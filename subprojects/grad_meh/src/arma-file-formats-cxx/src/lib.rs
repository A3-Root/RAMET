mod core_impl;
mod enum_impl;
mod odol_impl;
mod oprw_impl;
mod paa_impl;
mod pbo_impl;

use crate::oprw_impl::{create_wrp_from_buf, create_wrp_from_vec};
use std::{
    fs::File,
    io::{BufReader, Cursor},
};

use arma_file_formats::real_virtuality::{
    p3d::ODOL,
    paa::Paa,
    pbo::PboReader,
    rap::{Cfg, CfgClass, CfgEntry, EntryReturn},
};
use bridge::{EntryCxx, LodCxx, MipmapCxx, ODOLCxx, PboCxx, ResolutionEnumCxx};
use cxx::{CxxString, CxxVector};

pub struct OdolLazyReaderCxx {
    reader: Cursor<Vec<u8>>,
    odol: ODOL,
}

impl OdolLazyReaderCxx {
    pub fn read_lod(&mut self, resolution: ResolutionEnumCxx) -> anyhow::Result<LodCxx> {
        Ok(self
            .odol
            .read_lod(&mut self.reader, resolution.into())?
            .into())
    }

    pub fn get_odol(&self) -> ODOLCxx {
        self.odol.clone().into()
    }
}

pub fn create_odol_lazy_reader_vec(buf: &[u8]) -> anyhow::Result<Box<OdolLazyReaderCxx>> {
    create_odol_lazy_reader_internal(buf)
}

pub fn create_odol_lazy_reader(buf: &CxxVector<u8>) -> anyhow::Result<Box<OdolLazyReaderCxx>> {
    create_odol_lazy_reader_internal(buf.as_slice())
}

fn create_odol_lazy_reader_internal(buf: &[u8]) -> anyhow::Result<Box<OdolLazyReaderCxx>> {
    let mut reader = Cursor::new(buf.to_owned());

    let odol = ODOL::from_stream(&mut reader)?;

    Ok(Box::new(OdolLazyReaderCxx { reader, odol }))
}

pub struct PboReaderCxx {
    reader: PboReader<BufReader<File>>,
}

impl PboReaderCxx {
    pub fn get_entry(&mut self, entry_path: &CxxString) -> anyhow::Result<EntryCxx> {
        let entry = self.reader.get_entry(&entry_path.to_string())?;

        if let Some(entry) = entry {
            Ok(entry.into())
        } else {
            Err(anyhow::anyhow!(format!(
                "PBO: Entry {} not found",
                entry_path
            )))
        }
    }

    pub fn has_entry(&self, entry_path: &CxxString) -> bool {
        self.reader.pbo.has_entry(&entry_path.to_string())
    }

    pub fn get_entry_data(&mut self, entry_path: &CxxString) -> anyhow::Result<Vec<u8>> {
        if let Ok(entry) = self.get_entry(entry_path) {
            Ok(entry.data)
        } else {
            Ok(Vec::new())
        }
    }

    pub fn get_pbo(&self) -> PboCxx {
        self.reader.pbo.clone().into()
    }

    pub fn extract_single_file(
        &mut self,
        entry_path: &CxxString,
        out_path: &CxxString,
        full_path: bool,
    ) -> anyhow::Result<bool> {
        Ok(self
            .reader
            .extract_single_file(&entry_path.to_string(), &out_path.to_string(), full_path)
            .is_ok())
    }

    pub fn get_prefix(&self) -> String {
        self.reader.get_prefix()
    }
}

pub fn create_pbo_reader_path(path: &CxxString) -> anyhow::Result<Box<PboReaderCxx>> {
    let file = File::open(path.to_string())?;
    let reader = BufReader::new(file);

    let reader = PboReader::from_stream(reader)?;

    Ok(Box::new(PboReaderCxx { reader }))
}

pub fn get_mipmap_from_paa_vec(buf: &Vec<u8>, index: u32) -> anyhow::Result<MipmapCxx> {
    get_mipmap_from_paa_internal(buf.as_slice(), index)
}

fn get_mipmap_from_paa_internal(buf: &[u8], index: u32) -> anyhow::Result<MipmapCxx> {
    let result = std::panic::catch_unwind(|| {
        let mut cursor = Cursor::new(buf);
        let paa = Paa::from_reader(&mut cursor, Some(&[index; 1]))?;

        if let Some(mm) = paa.mipmaps.get(index as usize) {
            Ok(mm.clone().into())
        } else {
            Err(anyhow::anyhow!(format!(
                "PAA: Mipmap at index {} not found",
                index
            )))
        }
    });

    match result {
        Ok(inner) => inner,
        Err(panic_info) => {
            let msg = if let Some(s) = panic_info.downcast_ref::<&str>() {
                s.to_string()
            } else if let Some(s) = panic_info.downcast_ref::<String>() {
                s.clone()
            } else {
                "unknown panic".to_string()
            };
            Err(anyhow::anyhow!("PAA decode panicked: {}", msg))
        }
    }
}

pub fn get_mipmap_from_paa(buf: &CxxVector<u8>, index: u32) -> anyhow::Result<MipmapCxx> {
    get_mipmap_from_paa_internal(buf.as_slice(), index)
}

pub struct CfgCxx {
    _cfg: Cfg,
}

impl CfgCxx {
    fn get_entry(&mut self, config_path: &CxxVector<CxxString>) -> Option<EntryReturn> {
        // Rust moment
        let config_path: Vec<String> = config_path.into_iter().map(|s| s.to_string()).collect();
        let config_path: Vec<&str> = config_path.iter().map(|s| s.as_str()).collect();
        self._cfg.get_entry(&config_path)
    }

    pub fn get_entry_as_string(&mut self, config_path: &CxxVector<CxxString>) -> String {
        if let Some(entry) = self.get_entry(config_path) {
            entry.as_string().unwrap_or_default()
        } else {
            String::new()
        }
    }

    pub fn get_entry_as_number(
        &mut self,
        config_path: &CxxVector<CxxString>,
    ) -> anyhow::Result<i32> {
        if let Some(entry) = self.get_entry(config_path) {
            if let Some(val) = entry.as_long() {
                Ok(val)
            } else {
                Err(anyhow::anyhow!("Not a long value!"))
            }
        } else {
            Err(anyhow::Error::msg(format!(
                "Entry '{}' not found!",
                config_path
                    .iter()
                    .map(|x| x.to_str().unwrap_or_default())
                    .collect::<Vec<&str>>()
                    .join(" >> ")
            )))
        }
    }

    fn get_entry_as_array_float(
        self: &mut CfgCxx,
        config_path: &CxxVector<CxxString>,
    ) -> anyhow::Result<Vec<f32>> {
        if let Some(entry) = self.get_entry(config_path) {
            if let Some(val) = entry.as_array() {
                let mut arr = Vec::new();
                for v in val {
                    match v {
                        arma_file_formats::real_virtuality::rap::CfgValue::Float(f) => arr.push(f),
                        arma_file_formats::real_virtuality::rap::CfgValue::Long(l) => {
                            arr.push(l as f32)
                        }
                        _ => return Err(anyhow::anyhow!("Not a numeric value!")),
                    };
                }
                Ok(arr)
            } else {
                Err(anyhow::anyhow!("Not an array!"))
            }
        } else {
            Err(anyhow::Error::msg(format!(
                "Entry '{}' not found!",
                config_path
                    .iter()
                    .map(|x| x.to_str().unwrap_or_default())
                    .collect::<Vec<&str>>()
                    .join(" >> ")
            )))
        }
    }

    pub fn get_entry_as_entries(&mut self, config_path: &CxxVector<CxxString>) -> Vec<CfgEntryCxx> {
        if let Some(entry) = self.get_entry(config_path) {
            if let Some(class) = entry.as_class() {
                return class.entries.into_iter().map(|e| e.into()).collect();
            }
        }
        Vec::new()
    }
}

pub fn create_cfg_path(path: &CxxString) -> anyhow::Result<Box<CfgCxx>> {
    let file = File::open(path.to_string())?;
    let mut reader = BufReader::new(file);

    let cfg = Cfg::read(&mut reader)?;

    Ok(Box::new(CfgCxx { _cfg: cfg }))
}

pub fn create_cfg_vec(buf: &Vec<u8>) -> anyhow::Result<Box<CfgCxx>> {
    let mut reader = Cursor::new(buf);

    let cfg = Cfg::read(&mut reader)?;

    Ok(Box::new(CfgCxx { _cfg: cfg }))
}

pub struct CfgEntryCxx {
    entry: CfgEntry,
}

impl CfgEntryCxx {
    pub fn get_entry_as_class(&mut self) -> anyhow::Result<Box<CfgClassCxx>> {
        if let Some(class) = self.entry.as_class() {
            Ok(Box::new(class.into()))
        } else {
            Err(anyhow::anyhow!("Not a class"))
        }
    }
}

impl From<CfgEntry> for CfgEntryCxx {
    fn from(entry: CfgEntry) -> Self {
        Self { entry }
    }
}

pub struct CfgClassCxx {
    class: CfgClass,
}

impl CfgClassCxx {
    fn get_entry(&mut self, config_path: &CxxVector<CxxString>) -> Option<EntryReturn> {
        // Rust moment
        let config_path: Vec<String> = config_path.into_iter().map(|s| s.to_string()).collect();
        let config_path: Vec<&str> = config_path.iter().map(|s| s.as_str()).collect();
        self.class.get_entry(&config_path)
    }

    pub fn get_entry_as_string(&mut self, config_path: &CxxVector<CxxString>) -> String {
        if let Some(entry) = self.get_entry(config_path) {
            entry.as_string().unwrap_or_default()
        } else {
            String::new()
        }
    }

    pub fn get_entry_as_number(&mut self, config_path: &CxxVector<CxxString>) -> f32 {
        if let Some(entry) = self.get_entry(config_path) {
            entry
                .as_float()
                .or_else(|| Some(entry.as_long().unwrap_or_default() as f32))
                .unwrap_or_default()
            // return match entry {
            //     EntryReturn::Entry(e) => 0.0,
            //     EntryReturn::Value(v) => match v {
            //         CfgValue::Float(f) => f,
            //         CfgValue::Long(l) => l as f32,
            //         _ => 0.0,
            //     },
            // };
        } else {
            0.0
        }
    }

    pub fn get_class_name(&self) -> String {
        self.class.name.clone()
    }
}
impl From<CfgClass> for CfgClassCxx {
    fn from(class: CfgClass) -> Self {
        Self { class }
    }
}

fn check_for_magic_and_decompress_lzss_file(
    path: &CxxString,
    magic: &CxxVector<u8>,
) -> anyhow::Result<bool> {
    let magic: Vec<u8> = magic.iter().copied().collect();
    Ok(
        arma_file_formats::core::check_for_magic_and_decompress_lzss_file(
            path.to_string(),
            &magic,
        )?,
    )
}

#[cxx::bridge(namespace = "arma_file_formats::cxx")]
mod bridge {

    extern "Rust" {
        // RAP
        type CfgCxx;

        fn create_cfg_path(path: &CxxString) -> Result<Box<CfgCxx>>;
        fn create_cfg_vec(buf: &Vec<u8>) -> Result<Box<CfgCxx>>;
        fn get_entry_as_string(self: &mut CfgCxx, config_path: &CxxVector<CxxString>) -> String;
        fn get_entry_as_number(
            self: &mut CfgCxx,
            config_path: &CxxVector<CxxString>,
        ) -> Result<i32>;
        fn get_entry_as_array_float(
            self: &mut CfgCxx,
            config_path: &CxxVector<CxxString>,
        ) -> Result<Vec<f32>>;
        fn get_entry_as_entries(
            self: &mut CfgCxx,
            config_path: &CxxVector<CxxString>,
        ) -> Vec<CfgEntryCxx>;

        // WRP
        fn create_wrp_from_buf(buf: &CxxVector<u8>) -> Result<OprwCxx>;
        fn create_wrp_from_vec(buf: &Vec<u8>) -> Result<OprwCxx>;

        type CfgEntryCxx;
        fn get_entry_as_class(self: &mut CfgEntryCxx) -> Result<Box<CfgClassCxx>>;

        type CfgClassCxx;
        fn get_entry_as_string(
            self: &mut CfgClassCxx,
            config_path: &CxxVector<CxxString>,
        ) -> String;
        fn get_entry_as_number(self: &mut CfgClassCxx, config_path: &CxxVector<CxxString>) -> f32;
        fn get_class_name(self: &CfgClassCxx) -> String;

        /// P3D
        type OdolLazyReaderCxx;

        unsafe fn create_odol_lazy_reader(buf: &CxxVector<u8>) -> Result<Box<OdolLazyReaderCxx>>;

        unsafe fn create_odol_lazy_reader_vec(buf: &Vec<u8>) -> Result<Box<OdolLazyReaderCxx>>;

        fn read_lod(self: &mut OdolLazyReaderCxx, resolution: ResolutionEnumCxx) -> Result<LodCxx>;
        fn get_odol(self: &OdolLazyReaderCxx) -> ODOLCxx;

        // PBO
        type PboReaderCxx;

        unsafe fn create_pbo_reader_path(buf: &CxxString) -> Result<Box<PboReaderCxx>>;

        fn get_entry(self: &mut PboReaderCxx, entry_path: &CxxString) -> Result<EntryCxx>;
        fn get_entry_data(self: &mut PboReaderCxx, entry_path: &CxxString) -> Result<Vec<u8>>;
        fn get_pbo(self: &PboReaderCxx) -> PboCxx;
        fn has_entry(self: &PboReaderCxx, entry_path: &CxxString) -> bool;
        pub fn extract_single_file(
            self: &mut PboReaderCxx,
            entry_path: &CxxString,
            out_path: &CxxString,
            full_path: bool,
        ) -> Result<bool>;
        pub fn get_prefix(self: &PboReaderCxx) -> String;

        fn get_mipmap_from_paa(buf: &CxxVector<u8>, index: u32) -> Result<MipmapCxx>;
        fn get_mipmap_from_paa_vec(buf: &Vec<u8>, index: u32) -> Result<MipmapCxx>;

        // Util
        fn check_for_magic_and_decompress_lzss_file(
            path: &CxxString,
            magic: &CxxVector<u8>,
        ) -> Result<bool>;
    }

    #[derive(Debug)]
    pub struct MipmapCxx {
        pub width: u16,
        pub height: u16,
        pub data: Vec<u8>,
    }

    #[derive(Debug)]
    pub struct PboCxx {
        pub properties: Vec<PboPropertyCxx>,

        pub entries: Vec<EntryCxx>,

        pub hash: Vec<u8>,
    }

    #[derive(Debug)]
    pub struct EntryCxx {
        pub filename: String,
        pub mime_type: String,
        pub size: u32,
        pub timestamp: u32,

        pub data: Vec<u8>,
    }

    #[derive(Debug)]
    pub struct PboPropertyCxx {
        key: String,
        value: String,
    }

    #[derive(Debug)]
    pub struct OprwCxx {
        pub version: u32,
        pub app_id: u32,
        pub layer_size_x: u32,
        pub layer_size_y: u32,
        pub map_size_x: u32,
        pub map_size_y: u32,
        pub layer_cell_size: f32,
        pub map_size: u32,
        pub layer_size: u32,
        //geography: QuadTree,

        //sound_map: QuadTree,
        pub mountains: Vec<XYZTripletCxx>,
        // //rvmat_layer_index: QuadTree,
        pub random_clutter: Vec<u8>,
        pub grass: Vec<u8>,

        pub tex_index: Vec<u8>,

        pub elevation: Vec<f32>,
        pub texures: Vec<TextureCxx>,
        // model_count: u32,
        pub models: Vec<String>,

        // classed_model_count: u32,
        pub classed_models: Vec<ClassedModelCxx>,

        // //pub object_offsets: QuadTree,

        // //pub map_object_offsets: QuadTree,
        // unknown_bytes_0: Vec<u8>,

        // unknown_bytes_1: Vec<u8>,
        pub max_object_id: u32,

        // road_net_size: u32,
        pub road_net: Vec<RoadNetCxx>,
        pub objects: Vec<ObjectCxx>,

        pub map_infos_1: Vec<MapType1Cxx>,
        pub map_infos_2: Vec<MapType2Cxx>,
        pub map_infos_3: Vec<MapType3Cxx>,
        pub map_infos_4: Vec<MapType4Cxx>,
        pub map_infos_5: Vec<MapType5Cxx>,
        pub map_infos_35: Vec<MapType35Cxx>,
        pub map_info_river: Vec<MapTypeRiverCxx>,
    }

    #[derive(Debug)]
    pub struct XYZTripletCxx {
        pub x: f32,
        pub y: f32,
        pub z: f32,
    }

    #[derive(Debug)]
    pub struct TextureCxx {
        pub texture_filename: String,
        //flag: String,
    }

    #[derive(Debug)]
    pub struct ClassedModelCxx {
        pub class_name: String,
        pub model_path: String,
        pub pos: XYZTripletCxx,
        pub obj_id: u32,
    }

    #[derive(Debug)]
    pub struct RoadNetCxx {
        pub road_parts: Vec<RoadPartCxx>,
    }

    #[derive(Debug)]
    pub struct RoadPartCxx {
        pub positions: Vec<XYZTripletCxx>,

        pub types: Vec<u8>,

        pub object_id: u32,

        pub p3d_path: String,

        pub transform_matrix: TransformMatrixCxx,
    }

    #[derive(Debug)]
    pub struct TransformMatrixCxx {
        pub _0: XYZTripletCxx,
        pub _1: XYZTripletCxx,
        pub _2: XYZTripletCxx,
        pub _3: XYZTripletCxx,
    }

    #[derive(Debug)]
    pub struct ObjectCxx {
        pub object_id: u32,
        pub model_index: u32,
        pub transform_matrx: TransformMatrixCxx,

        pub shape_params: u32,
    }

    #[derive(Debug)]
    pub struct MapType1Cxx {
        type_id: u32,
        object_id: u32,
        x: f32,
        y: f32,
    }

    #[derive(Debug)]
    pub struct MapType2Cxx {
        type_id: u32,
        object_id: u32,
        bounds: BoundingBoxCxx,
    }

    #[derive(Debug)]
    pub struct MapType3Cxx {
        type_id: u32,
        color: u32,
        indicator: u32,
        floats: Vec<f32>,
    }

    #[derive(Debug)]
    pub struct MapType4Cxx {
        type_id: u32,
        object_id: u32,
        bounds: BoundingBoxCxx,
        color: Vec<u8>,
    }

    #[derive(Debug)]
    pub struct MapType5Cxx {
        type_id: u32,
        object_id: u32,
        floats: Vec<f32>, // minimal bounding box???
    }

    #[derive(Debug)]
    pub struct MapType35Cxx {
        type_id: u32,
        object_id: u32,
        line: Vec<f32>,
        unknown: u8,
    }

    #[derive(Debug)]
    pub struct MapTypeRiverCxx {
        type_id: u32,
        object_id: u32,
        polygon: Vec<XYCxx>,
    }

    #[derive(Debug)]
    pub struct BoundingBoxCxx {
        pub a: XYCxx,
        pub b: XYCxx,
        pub c: XYCxx,
        pub d: XYCxx,
    }

    #[derive(Debug)]
    pub struct XYCxx {
        pub x: f32,
        pub y: f32,
    }

    #[derive(Debug)]
    pub struct D3DColorValueCxx {
        pub r: f32,
        pub g: f32,
        pub b: f32,
        pub a: f32,
    }

    #[derive(Debug)]
    pub struct STPairCxx {
        pub s: XYZTripletCxx,
        pub t: XYZTripletCxx,
    }

    #[derive(Debug)]
    pub struct LodCxx {
        pub proxies: Vec<ProxyCxx>,

        pub lod_items: Vec<u32>,

        pub bone_links: Vec<BoneLinkCxx>,

        pub vertex_count: u32,

        pub clip_old_format: Vec<i32>,

        pub face_area: f32,

        pub or_hints: i32,
        pub and_hints: i32,
        pub b_min: XYZTripletCxx,
        pub b_max: XYZTripletCxx,
        pub b_center: XYZTripletCxx,
        pub b_radius: f32,

        pub textures: Vec<String>,

        pub materials: Vec<LodMaterialCxx>,

        pub lod_edges: LodEdgesCxx,

        pub faces: Vec<LodFaceCxx>,

        pub sections: Vec<LodSectionCxx>,

        pub named_selection: Vec<LodNameSelectionCxx>,

        pub named_properties: Vec<LodNamedPropertyCxx>,

        pub frames: Vec<LodFrameCxx>,

        pub icon_color: u32,
        pub selected_color: u32,
        pub special: u32,

        pub vertex_bone_ref_is_simple: bool,

        pub size_of_rest_data: u32,

        pub clip: Vec<u32>,

        pub default_uv_set: UVSetCxx,

        pub uv_sets: Vec<UVSetCxx>,

        pub vertices: Vec<XYZTripletCxx>,

        pub normals: Vec<XYZTripletCxx>,

        pub st_coords: Vec<STPairCxx>,

        pub vertex_bone_ref: Vec<AnimationRTWeightCxx>,

        pub neighbour_bone_ref: Vec<VertexNeighbourCxx>,
    }

    #[derive(Debug)]
    pub struct ProxyCxx {
        pub proxy_model: String,
        pub transformation: TransformMatrixCxx,
        pub sequence_id: i32,
        pub named_selection_index: i32,
        pub bone_index: i32,

        pub section_index: i32,
    }

    #[derive(Debug)]
    pub struct BoneLinkCxx {
        pub values: Vec<u32>,
    }

    #[derive(Debug)]
    pub struct LodMaterialCxx {
        pub material_name: String,

        pub version: u32,

        pub emissive: D3DColorValueCxx,
        pub ambient: D3DColorValueCxx,
        pub diffuse: D3DColorValueCxx,
        pub forced_diffuse: D3DColorValueCxx,
        pub specular: D3DColorValueCxx,
        pub specular_2: D3DColorValueCxx,

        pub specular_power: f32,

        pub pixel_shader: i32,
        pub vertex_shader: i32,
        pub main_light: i32,
        pub fog_mode: i32,

        pub surface_file: String,

        pub n_render_flags: u32,

        pub render_flags: u32,

        pub texture_count: u32,

        pub transform_count: u32,

        pub stage_textures: Vec<StageTextureCxx>,

        pub stage_transforms: Vec<StageTransformCxx>,

        pub dummy_stage_textures: StageTextureCxx,
    }

    #[derive(Debug)]
    pub struct StageTextureCxx {
        pub render_flags: u32,

        pub texture: String,

        pub stage_id: u32,

        pub use_world_env: bool,
    }

    #[derive(Debug)]
    pub struct StageTransformCxx {
        pub uv_source: u32,
        pub transformation: TransformMatrixCxx,
    }

    #[derive(Debug)]
    pub struct LodEdgesCxx {
        pub mlod_index: CompressedVertexIndexArrayCxx,

        pub vertex_index: CompressedVertexIndexArrayCxx,
    }

    #[derive(Debug)]
    pub struct CompressedVertexIndexArrayCxx {
        pub edges: Vec<u32>,
    }

    #[derive(Debug)]
    pub struct LodFaceCxx {
        pub face_type: u8,

        pub vertex_indices: Vec<u32>,
    }

    #[derive(Debug)]
    pub struct LodSectionCxx {
        pub short_indices: bool,

        pub face_lower_index: u32,
        pub face_upper_index: u32,

        pub min_bone_index: u32,
        pub bone_count: u32,

        pub common_point_user_value: u32,
        pub common_texture_index: i16,
        pub common_face_flag: u32,
        pub material_index: i32,

        pub material: String,

        pub stage_count: u32,

        pub stages: Vec<f32>,

        pub unk_matrix_exists: bool,

        pub unk_matrix: TransformMatrixCxx,
    }

    #[derive(Debug)]
    pub struct LodNameSelectionCxx {
        pub name: String,

        pub selected_faces: CompressedVertexIndexArrayCxx,

        pub is_sectional: bool,

        pub vertex_indices: Vec<i32>,

        pub selected_vertices: CompressedVertexIndexArrayCxx,

        pub selected_vertices_weights: Vec<u8>,
    }

    #[derive(Debug)]
    pub struct LodNamedPropertyCxx {
        pub property: String,
        pub value: String,
    }

    #[derive(Debug)]
    pub struct LodFrameCxx {
        pub frame_time: f32,
        pub bone_count: u32,

        pub bone_positions: Vec<XYZTripletCxx>,
    }

    #[derive(Debug)]
    pub struct UVSetCxx {
        pub is_discretized: bool,

        pub min_u: f32,

        pub min_v: f32,

        pub max_u: f32,

        pub max_v: f32,

        pub default_fill: bool,

        pub default_value: Vec<u8>,

        pub uv_data: Vec<u8>,
    }
    #[derive(Debug)]

    pub struct AnimationRTWeightCxx {
        pub small_count: i32,

        pub small_space: Vec<u8>,

        pub animation_rt_pairs: Vec<AnimationRTPairCxx>,
    }
    #[derive(Debug)]

    pub struct AnimationRTPairCxx {
        pub selection_index: u8,
        pub weight: u8,
    }

    #[derive(Debug)]
    pub struct VertexNeighbourCxx {
        pub pos_a: u16,

        pub rtw_a: AnimationRTWeightCxx,

        pub pos_b: u16,

        pub rtw_b: AnimationRTWeightCxx,
    }

    #[derive(Debug)]
    pub struct ClipFlagsCxx {
        pub value: i32,

        pub res: ClipFlagsEnumCxx,
    }

    #[derive(Debug)]
    pub enum ClipFlagsEnumCxx {
        ClipNoneNormal,
        ClipFront = 1,
        ClipBack = 2,
        ClipLeft = 4,
        ClipRight = 8,
        ClipBottom = 16,
        ClipTop = 32,
        ClipUser0 = 64,
        ClipAll = 63,
        ClipLandMask = 3840,
        ClipLandStep = 256,

        //ClipLandOn = 256,
        ClipLandUnder = 512,
        ClipLandAbove = 1024,
        ClipLandKeep = 2048,
        ClipDecalMask = 12288,
        ClipDecalStep = 4096,

        //ClipDecalNormal = 4096,
        ClipDecalVertical = 8192,
        ClipFogMask = 49152,
        ClipFogStep = 16384,

        //ClipFogDisable = 16384,
        ClipFogSky = 32768,
        ClipLightMask = 983040,
        ClipLightStep = 65536,

        ClipLightLine = 524288,
        ClipUserMask = 267386880,
        ClipUserStep = 1048576,
        MaxUserValue = 255,
        ClipHints = 268435200,
        Unknown,
    }

    #[derive(Debug)]
    #[allow(non_camel_case_types, clippy::enum_variant_names)]

    pub enum EFogModeCxx {
        None,
        Fog,
        Alpha,
        FogAlpha,
    }

    #[derive(Debug)]
    #[allow(non_camel_case_types, clippy::enum_variant_names)]

    pub enum EMainLightCxx {
        None,
        Sun,
        Sky,
        Horizon,
        Stars,
        SunObject,
        SunHaloObject,
        MoonObject,
        MoonHaloObject,
    }

    #[derive(Debug)]
    #[allow(
        non_camel_case_types,
        clippy::enum_variant_names,
        clippy::enum_clike_unportable_variant
    )]

    pub enum PixelShaderIDCxx {
        PSNormal,
        PSNormalDXTA,
        PSNormalMap,
        PSNormalMapThrough,
        PSNormalMapGrass,
        PSNormalMapDiffuse,
        PSDetail,
        PSInterpolation,
        PSWater,
        PSWaterSimple,
        PSWhite,
        PSWhiteAlpha,
        PSAlphaShadow,
        PSAlphaNoShadow,
        PSDummy0,
        PSDetailMacroAS,
        PSNormalMapMacroAS,
        PSNormalMapDiffuseMacroAS,
        PSNormalMapSpecularMap,
        PSNormalMapDetailSpecularMap,
        PSNormalMapMacroASSpecularMap,
        PSNormalMapDetailMacroASSpecularMap,
        PSNormalMapSpecularDIMap,
        PSNormalMapDetailSpecularDIMap,
        PSNormalMapMacroASSpecularDIMap,
        PSNormalMapDetailMacroASSpecularDIMap,
        PSTerrain1,
        PSTerrain2,
        PSTerrain3,
        PSTerrain4,
        PSTerrain5,
        PSTerrain6,
        PSTerrain7,
        PSTerrain8,
        PSTerrain9,
        PSTerrain10,
        PSTerrain11,
        PSTerrain12,
        PSTerrain13,
        PSTerrain14,
        PSTerrain15,
        PSTerrainSimple1,
        PSTerrainSimple2,
        PSTerrainSimple3,
        PSTerrainSimple4,
        PSTerrainSimple5,
        PSTerrainSimple6,
        PSTerrainSimple7,
        PSTerrainSimple8,
        PSTerrainSimple9,
        PSTerrainSimple10,
        PSTerrainSimple11,
        PSTerrainSimple12,
        PSTerrainSimple13,
        PSTerrainSimple14,
        PSTerrainSimple15,
        PSGlass,
        PSNonTL,
        PSNormalMapSpecularThrough,
        PSGrass,
        PSNormalMapThroughSimple,
        PSNormalMapSpecularThroughSimple,
        PSRoad,
        PSShore,
        PSShoreWet,
        PSRoad2Pass,
        PSShoreFoam,
        PSNonTLFlare,
        PSNormalMapThroughLowEnd,
        PSTerrainGrass1,
        PSTerrainGrass2,
        PSTerrainGrass3,
        PSTerrainGrass4,
        PSTerrainGrass5,
        PSTerrainGrass6,
        PSTerrainGrass7,
        PSTerrainGrass8,
        PSTerrainGrass9,
        PSTerrainGrass10,
        PSTerrainGrass11,
        PSTerrainGrass12,
        PSTerrainGrass13,
        PSTerrainGrass14,
        PSTerrainGrass15,
        PSCrater1,
        PSCrater2,
        PSCrater3,
        PSCrater4,
        PSCrater5,
        PSCrater6,
        PSCrater7,
        PSCrater8,
        PSCrater9,
        PSCrater10,
        PSCrater11,
        PSCrater12,
        PSCrater13,
        PSCrater14,
        PSSprite,
        PSSpriteSimple,
        PSCloud,
        PSHorizon,
        PSSuper,
        PSMulti,
        PSTerrainX,
        PSTerrainSimpleX,
        PSTerrainGrassX,
        PSTree,
        PSTreePRT,
        PSTreeSimple,
        PSSkin,
        PSCalmWater,
        PSTreeAToC,
        PSGrassAToC,
        PSTreeAdv,
        PSTreeAdvSimple,
        PSTreeAdvTrunk,
        PSTreeAdvTrunkSimple,
        PSTreeAdvAToC,
        PSTreeAdvSimpleAToC,
        PSTreeSN,
        PSSpriteExtTi,
        PSTerrainSNX,
        PSSimulWeatherClouds,
        PSSimulWeatherCloudsWithLightning,
        PSSimulWeatherCloudsCPU,
        PSSimulWeatherCloudsWithLightningCPU,
        PSSuperExt,
        PSSuperAToC,
        NPixelShaderID,
        //PSNone = 129,
        PSUninitialized = 4294967295,
    }

    #[derive(Debug)]
    pub struct VertextShaderIDCxx {
        pub v: i32,
        pub e: VertexShaderIDEnumCxx,
    }

    #[derive(Debug)]
    pub enum VertexShaderIDEnumCxx {
        VSBasic,
        VSNormalMap,
        VSNormalMapDiffuse,
        VSGrass,
        VSDummy1,
        VSDummy2,
        VSShadowVolume,
        VSWater,
        VSWaterSimple,
        VSSprite,
        VSPoint,
        VSNormalMapThrough,
        VSDummy3,
        VSTerrain,
        VSBasicAS,
        VSNormalMapAS,
        VSNormalMapDiffuseAS,
        VSGlass,
        VSNormalMapSpecularThrough,
        VSNormalMapThroughNoFade,
        VSNormalMapSpecularThroughNoFade,
        VSShore,
        VSTerrainGrass,
        VSSuper,
        VSMulti,
        VSTree,
        VSTreeNoFade,
        VSTreePRT,
        VSTreePRTNoFade,
        VSSkin,
        VSCalmWater,
        VSTreeAdv,
        VSTreeAdvTrunk,
        VSSimulWeatherClouds,
        VSSimulWeatherCloudsCPU,
        NVertexShaderID,
        Unknown,
    }

    #[derive(Debug)]
    pub enum UVSourceCxx {
        UVNone,
        UVTex,
        UVTexWaterAnim,
        UVPos,
        UVNorm,
        UVTex1,
        UVWorldPos,
        UVWorldNorm,
        UVTexShoreAnim,
        NUVSource,
    }

    #[derive(Debug)]
    pub enum TextureFilterTypeCxx {
        Point,
        Linear,
        Triliniear,
        Anisotropic,
    }

    #[derive(Debug)]
    pub struct ODOLCxx {
        pub version: u32,

        pub app_id: u32,

        pub p3d_prefix: String,

        pub lod_count: u32,

        pub resolutions: Vec<ResolutionCxx>,

        pub model_info: ModelInfoCxx,

        pub has_anims: bool,

        pub animations: AnimationsCxx,

        pub start_address_of_lods: Vec<u32>,

        pub end_address_of_lods: Vec<u32>,

        pub use_defaults: Vec<bool>,

        pub face_defaults: Vec<FaceDataCxx>,

        pub lods: Vec<LodCxx>,
    }

    #[derive(Debug)]
    pub struct ResolutionCxx {
        pub value: f32,

        pub res: ResolutionEnumCxx,
    }

    #[derive(Debug)]
    pub enum ResolutionEnumCxx {
        GraphicalLod,

        ViewGunner,

        ViewPilot,

        ViewCargo,

        ViewUnknown,

        ShadowVolume,

        ShadowVolume2,

        StencilShadow,

        StencilShadow2,

        StencilShadowUnknown,

        Geometry,

        Unknown4E13,

        Memory,

        LandContact,

        Roadway,

        Paths,

        HitPoints,

        ViewGeometry,

        FireGeometry,

        ViewCargoGeometry,

        ViewCargoFireGeometry,

        ViewCommander,

        ViewCommanderGeometry,

        ViewCommanderFireGeometry,

        ViewPilotGeometry,

        ViewPilotFireGeometry,

        ViewGunnerGeometry,

        ViewGunnerFireGeometry,

        SubParts,

        ShadowVolumeViewCargo,

        ShadowVolumeViewPilot,

        ShadowVolumeViewGunner,

        Wreck,

        Unknown, //(PhantomData<f32>),
    }

    #[derive(Debug)]
    pub struct SkeletonCxx {
        pub name: String,

        pub is_discrete: bool,

        pub skeleton_bones: Vec<BoneCxx>,

        pub pivots_name_obsolete: String,
    }

    #[derive(Debug)]
    pub struct BoneCxx {
        pub bone_name: String,
        pub bone_parent: String,
    }

    #[derive(Debug)]
    pub struct RGBAColorCxx {
        pub a: u8,
        pub b: u8,
        pub c: u8,
        pub d: u8,
    }

    #[derive(Debug)]
    pub struct ModelInfoCxx {
        pub index: u32,
        pub mem_lod_sphere: f32,
        pub geo_lod_sphere: f32,
        pub remarks: u32,
        pub and_hints: u32,
        pub or_hints: u32,
        pub aiming_center: XYZTripletCxx,
        pub map_icon_color: RGBAColorCxx,
        pub map_selected_color: RGBAColorCxx,
        pub view_density: f32,
        pub bbox_min_pos: XYZTripletCxx,
        pub bbox_max_pos: XYZTripletCxx,

        pub lod_density_coef: f32,

        pub draw_importance: f32,

        pub bbox_min_visual: XYZTripletCxx,

        pub bbox_max_visual: XYZTripletCxx,

        pub bounding_center: XYZTripletCxx,
        pub geometry_center: XYZTripletCxx,
        pub center_of_mass: XYZTripletCxx,

        pub inv_intertia: Vec<XYZTripletCxx>,

        pub auto_center: bool,

        pub lock_auto_center: bool,

        pub can_occlude: bool,

        pub can_be_occlude: bool,

        pub ai_covers: bool,

        pub ht_min: f32,

        pub ht_max: f32,

        pub af_max: f32,

        pub mf_max: f32,

        pub m_fact: f32,

        pub t_body: f32,

        pub force_not_alpha: bool,

        pub sb_source: SBSourceCxx,

        pub prefer_shadow_volume: bool,

        pub shadow_offset: f32,

        pub animated: bool,

        pub skeleton: SkeletonCxx,

        pub map_type: u8,

        pub mass_array: Vec<f32>,

        pub mass: f32,
        pub mass_reciprocal: f32,
        pub alt_mass: f32,
        pub alt_mass_reciprocal: f32,

        pub property_explosion_shielding: f32,

        pub geometry_simple: u8,

        pub geometry_phys: u8,

        pub memory: u8,
        pub geometry: u8,
        pub geometry_fire: u8,
        pub geometry_view: u8,
        pub geometry_view_pilot: u8,
        pub geometry_view_gunner: u8,
        pub unknown_signedbyte: i8,
        pub geometry_view_cargo: u8,
        pub land_contact: u8,
        pub roadway: u8,
        pub paths: u8,
        pub hitpoints: u8,
        pub min_shadow: u32,

        pub can_blend: bool,

        pub property_class: String,
        pub property_damage: String,
        pub property_frequent: String,

        pub unknown_int: u32,

        pub prefferred_shadow_volumne_lod: Vec<i32>,

        pub prefferred_shadow_buffer_lod: Vec<i32>,

        pub prefferred_shadow_buffer_lod_vis: Vec<i32>,
    }

    #[derive(Debug)]
    #[allow(non_camel_case_types, clippy::enum_variant_names)]
    pub enum SBSourceCxx {
        Visual = 0,

        ShadowVolume = 1,

        Explicit = 2,

        None = 3,

        VisualEx = 4,
    }

    #[derive(Debug)]
    #[allow(non_camel_case_types, clippy::enum_variant_names)]
    pub enum MapTypeCxx {
        MapTree = 0,
        MapSmallTree = 1,
        MapBush = 2,
        MapBuilding = 3,
        MapHouse = 4,
        MapForestBorder = 5,
        MapForestTriangle = 6,
        MapForestSquare = 7,
        MapChurch = 8,
        MapChapel = 9,
        MapCross = 10,
        MapRock = 11,
        MapBunker = 12,
        MapFortress = 13,
        MapFountain = 14,
        MapViewTower = 15,
        MapLighthouse = 16,
        MapQuay = 17,
        MapFuelstation = 18,
        MapHospital = 19,
        MapFence = 20,
        MapWall = 21,
        MapHide = 22,
        MapBusStop = 23,
        MapRoad = 24,
        MapForest = 25,
        MapTransmitter = 26,
        MapStack = 27,
        MapRuin = 28,
        MapTourism = 29,
        MapWatertower = 30,
        MapTrack = 31,
        MapMainRoad = 32,
        MapRocks = 33,
        MapPowerLines = 34,
        MapRailWay = 35,
        NMapTypes = 36,
    }

    #[derive(Debug)]
    pub struct FaceDataCxx {
        pub header_face_count: u32,
        pub color: u32,
        pub special: i32,
        pub or_hints: u32,

        pub has_skeleton: bool,

        pub vertices_count: i32,

        pub face_area: f32,
    }

    #[derive(Debug)]
    pub struct AnimationsCxx {
        pub animation_classes: Vec<AnimationClassCxx>,

        pub bones_2_anims: Vec<Bones2AnimsCxx>,

        pub anims_2_bones: Vec<Anims2BonesCxx>,
    }

    #[derive(Debug)]
    pub struct AnimationClassCxx {
        pub anim_transform_type: AnimTypeCxx,
        pub anim_class_name: String,
        pub anim_source: String,
        pub min_phase: f32,
        pub max_phase: f32,
        pub min_value: f32,
        pub max_value: f32,

        pub anim_period: f32,

        pub init_phase: f32,

        pub source_address: AnimAddressCxx,

        pub angle_0: f32,
        pub angle_1: f32,

        pub offset_0: f32,
        pub offset_1: f32,

        pub axis_pos: XYZTripletCxx,

        pub axis_dir: XYZTripletCxx,

        pub axis_angle: f32,

        pub axis_offset: f32,

        pub hide_value: f32,

        pub unknown_hide: f32,
    }

    #[derive(Debug)]
    #[allow(non_camel_case_types, clippy::enum_variant_names)]
    pub enum AnimTypeCxx {
        Rotation = 0,
        RotationX = 1,
        RotationY = 2,
        RotationZ = 3,
        Translation = 4,
        TranslationX = 5,
        TranslationY = 6,
        TranslationZ = 7,
        Direct = 8,
        Hide = 9,
    }

    #[derive(Debug)]
    #[allow(non_camel_case_types, clippy::enum_variant_names)]
    pub enum AnimAddressCxx {
        AnimClamp = 0,
        AnimLoop = 1,
        AnimMirror = 2,
        NAnimAddress = 3,
    }

    #[derive(Debug)]
    pub struct Bones2AnimsCxx {
        pub bone_2_anim_class_list: Vec<Bone2AnimClassListCxx>,
    }

    #[derive(Debug)]
    pub struct Bone2AnimClassListCxx {
        pub animation_class_index: Vec<u32>,
    }

    #[derive(Debug)]
    pub struct Anims2BonesCxx {
        pub animation_class_indices: Vec<AnimBonesCxx>,
    }

    #[derive(Debug)]
    pub struct AnimBonesCxx {
        pub skeleton_bone_name_index: i32,

        pub axis_pos: XYZTripletCxx,
        pub axis_dir: XYZTripletCxx,
    }
}

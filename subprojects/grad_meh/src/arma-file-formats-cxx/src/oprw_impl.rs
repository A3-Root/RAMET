use std::io::Cursor;

use arma_file_formats::real_virtuality::wrp::{
    ClassedModel, MapData, Object, RoadNet, RoadPart, Texture,
};
use cxx::CxxVector;

use crate::bridge::{
    self, ClassedModelCxx, MapType1Cxx, MapType2Cxx, MapType3Cxx, MapType4Cxx, MapType5Cxx,
    MapType35Cxx, MapTypeRiverCxx, ObjectCxx, OprwCxx, RoadNetCxx, RoadPartCxx, TextureCxx,
};

impl From<Texture> for TextureCxx {
    fn from(value: Texture) -> Self {
        Self {
            texture_filename: value.texture_filename.to_string(),
        }
    }
}

impl From<RoadNet> for RoadNetCxx {
    fn from(value: RoadNet) -> Self {
        Self {
            road_parts: value.road_parts.into_iter().map(|rp| rp.into()).collect(),
        }
    }
}

impl From<RoadPart> for RoadPartCxx {
    fn from(value: RoadPart) -> Self {
        Self {
            positions: value.positions.into_iter().map(|p| p.into()).collect(),
            types: value.types.unwrap_or_default(),
            object_id: value.object_id,
            p3d_path: value.p3d_path.unwrap_or_default().to_string(),
            transform_matrix: value.transform_matrix.unwrap_or_default().into(),
        }
    }
}

impl From<ClassedModel> for ClassedModelCxx {
    fn from(value: ClassedModel) -> Self {
        Self {
            class_name: value.class_name.to_string(),
            model_path: value.model_path.to_string(),
            pos: value.pos.into(),
            obj_id: value.obj_id,
        }
    }
}

impl From<Object> for ObjectCxx {
    fn from(value: Object) -> Self {
        Self {
            object_id: value.object_id,
            model_index: value.model_index,
            transform_matrx: value.transform_matrx.into(),
            shape_params: value.shape_params.unwrap_or_default(),
        }
    }
}

impl From<arma_file_formats::real_virtuality::wrp::OPRW> for bridge::OprwCxx {
    fn from(v: arma_file_formats::real_virtuality::wrp::OPRW) -> Self {
        //for

        let mut oprw_cxx = bridge::OprwCxx {
            version: v.version,
            app_id: v.app_id.unwrap_or_default(),
            layer_size_x: v.layer_size_x.unwrap_or_default(),
            layer_size_y: v.layer_size_y.unwrap_or_default(),
            map_size_x: v.map_size_x.unwrap_or_default(),
            map_size_y: v.map_size_y.unwrap_or_default(),
            layer_cell_size: v.layer_cell_size.unwrap_or_default(),
            map_size: v.map_size.unwrap_or_default(),
            layer_size: v.layer_size.unwrap_or_default(),
            mountains: v.mountains.into_iter().map(|m| m.into()).collect(),
            random_clutter: v.random_clutter.unwrap_or_default(),
            grass: v.grass.unwrap_or_default(),
            tex_index: v.tex_index.unwrap_or_default(),
            elevation: v.elevation,
            texures: v.texures.into_iter().map(|t| t.into()).collect(),
            models: v.models.into_iter().map(|m| m.to_string()).collect(),
            classed_models: v
                .classed_models
                .unwrap_or_default()
                .into_iter()
                .map(|cm| cm.into())
                .collect(),

            max_object_id: v.max_object_id,
            road_net: v.road_net.into_iter().map(|rn| rn.into()).collect(),
            objects: v.objects.into_iter().map(|o| o.into()).collect(),
            map_infos_1: Vec::new(),
            map_infos_2: Vec::new(),
            map_infos_3: Vec::new(),
            map_infos_4: Vec::new(),
            map_infos_5: Vec::new(),
            map_infos_35: Vec::new(),
            map_info_river: Vec::new(),
        };

        for map_info in v.map_infos {
            match map_info.data {
                MapData::MapType1 { object_id, x, y } => oprw_cxx.map_infos_1.push(MapType1Cxx {
                    object_id,
                    x,
                    y,
                    type_id: map_info.id,
                }),
                MapData::MapType2 { object_id, bounds } => oprw_cxx.map_infos_2.push(MapType2Cxx {
                    object_id,
                    bounds: bounds.into(),
                    type_id: map_info.id,
                }),
                MapData::MapType3 {
                    color,
                    indicator,
                    floats,
                } => oprw_cxx.map_infos_3.push(MapType3Cxx {
                    color,
                    indicator,
                    floats,
                    type_id: map_info.id,
                }),
                MapData::MapType4 {
                    object_id,
                    bounds,
                    color,
                } => oprw_cxx.map_infos_4.push(MapType4Cxx {
                    object_id,
                    bounds: bounds.into(),
                    color,
                    type_id: map_info.id,
                }),
                MapData::MapType5 { object_id, floats } => oprw_cxx.map_infos_5.push(MapType5Cxx {
                    object_id,
                    floats,
                    type_id: map_info.id,
                }),
                MapData::MapType35 {
                    object_id,
                    line,
                    unknown,
                } => oprw_cxx.map_infos_35.push(MapType35Cxx {
                    object_id,
                    line,
                    unknown,
                    type_id: map_info.id,
                }),
                MapData::MapTypeRiver {
                    object_id, polygon, ..
                } => oprw_cxx.map_info_river.push(MapTypeRiverCxx {
                    type_id: map_info.id,
                    object_id,
                    polygon: polygon.iter().map(|x| (*x).into()).collect(),
                }),
                _ => unreachable!(),
            }
        }

        oprw_cxx
    }
}

pub fn create_wrp_from_buf(buf: &CxxVector<u8>) -> anyhow::Result<OprwCxx> {
    create_wrp_from_vec(buf.as_slice())
}

pub fn create_wrp_from_vec(buf: &[u8]) -> anyhow::Result<OprwCxx> {
    let mut cursor = Cursor::new(buf);

    let oprw = arma_file_formats::real_virtuality::wrp::OPRW::from_read(&mut cursor)?;

    Ok(oprw.into())
}

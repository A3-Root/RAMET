use arma_file_formats::real_virtuality::{
    p3d::{
        AnimBones, AnimationClass, AnimationRTPair, AnimationRTWeight, Animations, Anims2Bones,
        Bone, Bone2AnimClassList, BoneLink, Bones2Anims, CompressedVertexIndexArray, FaceData, Lod,
        LodEdges, LodFace, LodFrame, LodMaterial, LodNameSelection, LodNamedProperty, LodSection,
        ModelInfo, ODOL, Proxy, Resolution, Skeleton, StageTexture, StageTransform, UVSet,
        VertexNeighbour,
    },
    types::STPair,
};

use crate::bridge::{
    AnimBonesCxx, AnimationClassCxx, AnimationRTPairCxx, AnimationRTWeightCxx, AnimationsCxx,
    Anims2BonesCxx, Bone2AnimClassListCxx, BoneCxx, BoneLinkCxx, Bones2AnimsCxx,
    CompressedVertexIndexArrayCxx, FaceDataCxx, LodCxx, LodEdgesCxx, LodFaceCxx, LodFrameCxx,
    LodMaterialCxx, LodNameSelectionCxx, LodNamedPropertyCxx, LodSectionCxx, ModelInfoCxx, ODOLCxx,
    ProxyCxx, ResolutionCxx, STPairCxx, SkeletonCxx, StageTextureCxx, StageTransformCxx, UVSetCxx,
    VertexNeighbourCxx,
};

impl From<BoneLink> for BoneLinkCxx {
    fn from(value: BoneLink) -> Self {
        Self {
            values: value.values,
        }
    }
}

impl From<Proxy> for ProxyCxx {
    fn from(v: Proxy) -> Self {
        Self {
            proxy_model: v.proxy_model.to_string(),
            transformation: v.transofrmation.into(),
            sequence_id: v.sequence_id,
            named_selection_index: v.named_selection_index,
            bone_index: v.bone_index,
            section_index: v.section_index,
        }
    }
}

impl From<Lod> for LodCxx {
    fn from(v: Lod) -> Self {
        Self {
            proxies: v.proxies.into_iter().map(|p| p.into()).collect(),
            lod_items: v.lod_items,
            bone_links: v.bone_links.into_iter().map(|bl| bl.into()).collect(),
            vertex_count: v.vertex_count.unwrap_or_default(),
            clip_old_format: v.clip_old_format.unwrap_or_default(),
            face_area: v.face_area.unwrap_or_default(),
            or_hints: v.or_hints,
            and_hints: v.and_hints,
            b_min: v.b_min.into(),
            b_max: v.b_max.into(),
            b_center: v.b_center.into(),
            b_radius: v.b_radius,
            textures: v.textures.into_iter().map(|t| t.to_string()).collect(),
            materials: v.materials.into_iter().map(|m| m.into()).collect(),
            lod_edges: v.lod_edges.into(),
            faces: v.faces.into_iter().map(|f| f.into()).collect(),
            sections: v.sections.into_iter().map(|s| s.into()).collect(),
            named_selection: v.named_selection.into_iter().map(|ns| ns.into()).collect(),
            named_properties: v.named_properties.into_iter().map(|np| np.into()).collect(),
            frames: v.frames.into_iter().map(|f| f.into()).collect(),
            icon_color: v.icon_color,
            selected_color: v.selected_color,
            special: v.special,
            vertex_bone_ref_is_simple: v.vertex_bone_ref_is_simple,
            size_of_rest_data: v.size_of_rest_data,
            clip: v.clip.unwrap_or_default(),
            default_uv_set: v.default_uv_set.into(),
            uv_sets: v.uv_sets.into_iter().map(|uvs| uvs.into()).collect(),
            vertices: v.vertices.into_iter().map(|v| v.into()).collect(),
            normals: v.normals.into_iter().map(|n| n.into()).collect(),
            st_coords: v.st_coords.into_iter().map(|stc| stc.into()).collect(),
            vertex_bone_ref: v
                .vertex_bone_ref
                .into_iter()
                .map(|vbr| vbr.into())
                .collect(),
            neighbour_bone_ref: v
                .neighbour_bone_ref
                .into_iter()
                .map(|nbr| nbr.into())
                .collect(),
        }
    }
}

impl From<UVSet> for UVSetCxx {
    fn from(v: UVSet) -> Self {
        Self {
            is_discretized: v.is_discretized,
            min_u: v.min_u.unwrap_or_default(),
            min_v: v.min_v.unwrap_or_default(),
            max_u: v.max_u.unwrap_or_default(),
            max_v: v.max_v.unwrap_or_default(),
            default_fill: v.default_fill,
            default_value: v.default_value.unwrap_or_default(),
            uv_data: v.uv_data.unwrap_or_default(),
        }
    }
}

impl From<STPair> for STPairCxx {
    fn from(value: STPair) -> Self {
        Self {
            s: value.s.into(),
            t: value.t.into(),
        }
    }
}

impl From<Skeleton> for SkeletonCxx {
    fn from(value: Skeleton) -> Self {
        Self {
            name: value.name.to_string(),
            is_discrete: value.is_discrete.unwrap_or_default(),
            skeleton_bones: value
                .skeleton_bones
                .into_iter()
                .map(|sb| sb.into())
                .collect(),
            pivots_name_obsolete: value.pivots_name_obsolete.unwrap_or_default().to_string(),
        }
    }
}

impl From<Bone> for BoneCxx {
    fn from(value: Bone) -> Self {
        Self {
            bone_name: value.bone_name.to_string(),
            bone_parent: value.bone_parent.to_string(),
        }
    }
}

impl From<Animations> for AnimationsCxx {
    fn from(value: Animations) -> Self {
        Self {
            animation_classes: value
                .animation_classes
                .into_iter()
                .map(|ac| ac.into())
                .collect(),
            bones_2_anims: value
                .bones_2_anims
                .into_iter()
                .map(|b2a| b2a.into())
                .collect(),
            anims_2_bones: value
                .anims_2_bones
                .into_iter()
                .map(|a2b| a2b.into())
                .collect(),
        }
    }
}

impl From<AnimationClass> for AnimationClassCxx {
    fn from(v: AnimationClass) -> Self {
        Self {
            anim_transform_type: v.anim_transform_type.into(),
            anim_class_name: v.anim_class_name.to_string(),
            anim_source: v.anim_source.to_string(),
            min_phase: v.min_phase,
            max_phase: v.max_phase,
            min_value: v.min_value,
            max_value: v.max_value,
            anim_period: v.anim_period.unwrap_or_default(),
            init_phase: v.init_phase.unwrap_or_default(),
            source_address: v.source_address.into(),
            angle_0: v.angle_0.unwrap_or_default(),
            angle_1: v.angle_1.unwrap_or_default(),
            offset_0: v.offset_0.unwrap_or_default(),
            offset_1: v.offset_1.unwrap_or_default(),
            axis_pos: v.axis_pos.unwrap_or_default().into(),
            axis_dir: v.axis_dir.unwrap_or_default().into(),
            axis_angle: v.axis_angle.unwrap_or_default(),
            axis_offset: v.axis_offset.unwrap_or_default(),
            hide_value: v.hide_value.unwrap_or_default(),
            unknown_hide: v.unknown_hide.unwrap_or_default(),
        }
    }
}

impl From<AnimBones> for AnimBonesCxx {
    fn from(value: AnimBones) -> Self {
        Self {
            skeleton_bone_name_index: value.skeleton_bone_name_index,
            axis_pos: value.axis_pos.unwrap_or_default().into(),
            axis_dir: value.axis_dir.unwrap_or_default().into(),
        }
    }
}

impl From<Anims2Bones> for Anims2BonesCxx {
    fn from(value: Anims2Bones) -> Self {
        Self {
            animation_class_indices: value
                .animation_class_indices
                .into_iter()
                .map(|aci| aci.into())
                .collect(),
        }
    }
}

impl From<Bone2AnimClassList> for Bone2AnimClassListCxx {
    fn from(value: Bone2AnimClassList) -> Self {
        Self {
            animation_class_index: value.animation_class_index,
        }
    }
}

impl From<Bones2Anims> for Bones2AnimsCxx {
    fn from(value: Bones2Anims) -> Self {
        Self {
            bone_2_anim_class_list: value
                .bone_2_anim_class_list
                .into_iter()
                .map(|b2acl| b2acl.into())
                .collect(),
        }
    }
}

impl From<FaceData> for FaceDataCxx {
    fn from(v: FaceData) -> Self {
        Self {
            header_face_count: v.header_face_count,
            color: v.color,
            special: v.special,
            or_hints: v.or_hints,
            has_skeleton: v.has_skeleton.unwrap_or_default(),
            vertices_count: v.vertices_count,
            face_area: v.face_area,
        }
    }
}

impl From<AnimationRTPair> for AnimationRTPairCxx {
    fn from(value: AnimationRTPair) -> Self {
        Self {
            selection_index: value.selection_index,
            weight: value.weight,
        }
    }
}

impl From<AnimationRTWeight> for AnimationRTWeightCxx {
    fn from(v: AnimationRTWeight) -> Self {
        Self {
            small_count: v.small_count,
            small_space: v.small_space,
            animation_rt_pairs: v
                .animation_rt_pairs
                .into_iter()
                .map(|arp| arp.into())
                .collect(),
        }
    }
}

impl From<VertexNeighbour> for VertexNeighbourCxx {
    fn from(v: VertexNeighbour) -> Self {
        Self {
            pos_a: v.pos_a,
            rtw_a: v.rtw_a.into(),
            pos_b: v.pos_b,
            rtw_b: v.rtw_b.into(),
        }
    }
}

impl From<LodFrame> for LodFrameCxx {
    fn from(v: LodFrame) -> Self {
        Self {
            frame_time: v.frame_time,
            bone_count: v.bone_count,
            bone_positions: v.bone_positions.into_iter().map(|bp| bp.into()).collect(),
        }
    }
}

impl From<LodNamedProperty> for LodNamedPropertyCxx {
    fn from(v: LodNamedProperty) -> Self {
        Self {
            property: v.property.to_string(),
            value: v.value.to_string(),
        }
    }
}

impl From<LodNameSelection> for LodNameSelectionCxx {
    fn from(v: LodNameSelection) -> Self {
        Self {
            name: v.name.to_string(),
            selected_faces: v.selected_faces.into(),
            is_sectional: v.is_sectional,
            vertex_indices: v.vertex_indices,
            selected_vertices: v.selected_vertices.into(),
            selected_vertices_weights: v.selected_vertices_weights,
        }
    }
}

impl From<CompressedVertexIndexArray> for CompressedVertexIndexArrayCxx {
    fn from(value: CompressedVertexIndexArray) -> Self {
        Self { edges: value.edges }
    }
}

impl From<LodSection> for LodSectionCxx {
    fn from(v: LodSection) -> Self {
        Self {
            short_indices: v.short_indices,
            face_lower_index: v.face_lower_index,
            face_upper_index: v.face_upper_index,
            min_bone_index: v.min_bone_index,
            bone_count: v.bone_count,
            common_point_user_value: v.common_point_user_value,
            common_texture_index: v.common_texture_index,
            common_face_flag: v.common_face_flag,
            material_index: v.material_index,
            material: v.material.unwrap_or_default().to_string(),
            stage_count: v.stage_count,
            stages: v.stages.unwrap_or_default(),
            unk_matrix_exists: v.unk_matrix_exists,
            unk_matrix: v.unk_matrix.into(),
        }
    }
}

impl From<LodFace> for LodFaceCxx {
    fn from(v: LodFace) -> Self {
        Self {
            face_type: v.face_type,
            vertex_indices: v.vertex_indices,
        }
    }
}

impl From<LodEdges> for LodEdgesCxx {
    fn from(v: LodEdges) -> Self {
        Self {
            mlod_index: v.mlod_index.into(),
            vertex_index: v.vertex_index.into(),
        }
    }
}

impl From<StageTransform> for StageTransformCxx {
    fn from(v: StageTransform) -> Self {
        Self {
            uv_source: v.uv_source,
            transformation: v.transformation.into(),
        }
    }
}

impl From<StageTexture> for StageTextureCxx {
    fn from(v: StageTexture) -> Self {
        Self {
            render_flags: v.render_flags.unwrap_or_default(),
            texture: v.texture.to_string(),
            stage_id: v.stage_id.unwrap_or_default(),
            use_world_env: v.use_world_env.unwrap_or_default(),
        }
    }
}

impl From<LodMaterial> for LodMaterialCxx {
    fn from(v: LodMaterial) -> Self {
        Self {
            material_name: v.material_name.to_string(),
            version: v.version,
            emissive: v.emissive.into(),
            ambient: v.ambient.into(),
            diffuse: v.diffuse.into(),
            forced_diffuse: v.forced_diffuse.into(),
            specular: v.specular.into(),
            specular_2: v.specular_2.into(),
            specular_power: v.specular_power,
            pixel_shader: v.pixel_shader,
            vertex_shader: v.vertex_shader,
            main_light: v.main_light,
            fog_mode: v.fog_mode,
            surface_file: v.surface_file.unwrap_or_default().to_string(),
            n_render_flags: v.n_render_flags.unwrap_or_default(),
            render_flags: v.render_flags.unwrap_or_default(),
            texture_count: v.texture_count,
            transform_count: v.transform_count,
            stage_textures: v.stage_textures.into_iter().map(|st| st.into()).collect(),
            stage_transforms: v.stage_transforms.into_iter().map(|st| st.into()).collect(),
            dummy_stage_textures: v.dummy_stage_textures.unwrap_or_default().into(),
        }
    }
}

impl From<ODOL> for ODOLCxx {
    fn from(v: ODOL) -> Self {
        Self {
            version: v.version,
            app_id: v.app_id,
            p3d_prefix: v.p3d_prefix.unwrap_or_default().to_string(),
            lod_count: v.lod_count,
            resolutions: v.resolutions.into_iter().map(|r| r.into()).collect(),
            model_info: v.model_info.into(),
            has_anims: v.has_anims.unwrap_or_default(),
            animations: v.animations.unwrap_or_default().into(),
            start_address_of_lods: v.start_address_of_lods,
            end_address_of_lods: v.end_address_of_lods,
            use_defaults: v.use_defaults,
            face_defaults: v
                .face_defaults
                .into_iter()
                .map(|fd| fd.unwrap_or_default().into())
                .collect(),
            lods: Vec::new(),
        }
    }
}

impl From<Resolution> for ResolutionCxx {
    fn from(value: Resolution) -> Self {
        Self {
            value: value.value,
            res: value.res.into(),
        }
    }
}

impl From<ModelInfo> for ModelInfoCxx {
    fn from(v: ModelInfo) -> Self {
        Self {
            index: v.index,
            mem_lod_sphere: v.mem_lod_sphere,
            geo_lod_sphere: v.geo_lod_sphere,
            remarks: v.remarks,
            and_hints: v.and_hints,
            or_hints: v.or_hints,
            aiming_center: v.aiming_center.into(),
            map_icon_color: v.map_icon_color.into(),
            map_selected_color: v.map_selected_color.into(),
            view_density: v.view_density,
            bbox_min_pos: v.bbox_min_pos.into(),
            bbox_max_pos: v.bbox_max_pos.into(),
            lod_density_coef: v.lod_density_coef.unwrap_or_default(),
            draw_importance: v.draw_importance.unwrap_or_default(),
            bbox_min_visual: v.bbox_min_visual.unwrap_or_default().into(),
            bbox_max_visual: v.bbox_max_visual.unwrap_or_default().into(),
            bounding_center: v.bounding_center.into(),
            geometry_center: v.geometry_center.into(),
            center_of_mass: v.center_of_mass.into(),
            inv_intertia: v.inv_intertia.into_iter().map(|ii| ii.into()).collect(),
            auto_center: v.auto_center,
            lock_auto_center: v.lock_auto_center,
            can_occlude: v.can_occlude,
            can_be_occlude: v.can_be_occlude,
            ai_covers: v.ai_covers.unwrap_or_default(),
            ht_min: v.ht_min.unwrap_or_default(),
            ht_max: v.ht_max.unwrap_or_default(),
            af_max: v.af_max.unwrap_or_default(),
            mf_max: v.mf_max.unwrap_or_default(),
            m_fact: v.m_fact.unwrap_or_default(),
            t_body: v.t_body.unwrap_or_default(),
            force_not_alpha: v.force_not_alpha.unwrap_or_default(),
            sb_source: v.sb_source.unwrap_or_default().into(),
            prefer_shadow_volume: v.prefer_shadow_volume.unwrap_or_default(),
            shadow_offset: v.shadow_offset.unwrap_or_default(),
            animated: v.animated,
            skeleton: v.skeleton.into(),
            map_type: v.map_type,
            mass_array: v.mass_array,
            mass: v.mass,
            mass_reciprocal: v.mass_reciprocal,
            alt_mass: v.alt_mass,
            alt_mass_reciprocal: v.alt_mass_reciprocal,
            property_explosion_shielding: v.property_explosion_shielding.unwrap_or_default(),
            geometry_simple: v.geometry_simple.unwrap_or_default(),
            geometry_phys: v.geometry_phys.unwrap_or_default(),
            memory: v.memory,
            geometry: v.geometry,
            geometry_fire: v.geometry_fire,
            geometry_view: v.geometry_view,
            geometry_view_pilot: v.geometry_view_pilot,
            geometry_view_gunner: v.geometry_view_gunner,
            unknown_signedbyte: v.unknown_signedbyte,
            geometry_view_cargo: v.geometry_view_cargo,
            land_contact: v.land_contact,
            roadway: v.roadway,
            paths: v.paths,
            hitpoints: v.hitpoints,
            min_shadow: v.min_shadow,
            can_blend: v.can_blend.unwrap_or_default(),
            property_class: v.property_class.to_string(),
            property_damage: v.property_damage.to_string(),
            property_frequent: v.property_frequent.to_string(),
            unknown_int: v.unknown_int,
            prefferred_shadow_volumne_lod: v.prefferred_shadow_volumne_lod.unwrap_or_default(),
            prefferred_shadow_buffer_lod: v.prefferred_shadow_buffer_lod.unwrap_or_default(),
            prefferred_shadow_buffer_lod_vis: v
                .prefferred_shadow_buffer_lod_vis
                .unwrap_or_default(),
        }
    }
}

use std::marker::PhantomData;

use arma_file_formats::real_virtuality::p3d::{
    AnimAddress, AnimType, ClipFlags, ClipFlagsEnum, EFogMode, EMainLight, MapType, PixelShaderID,
    ResolutionEnum, SBSource, TextureFilterType, UVSource, VertexShaderID, VertexShaderIDEnum,
};

use crate::bridge::{
    AnimAddressCxx, AnimTypeCxx, ClipFlagsCxx, ClipFlagsEnumCxx, EFogModeCxx, EMainLightCxx,
    MapTypeCxx, PixelShaderIDCxx, ResolutionEnumCxx, SBSourceCxx, TextureFilterTypeCxx,
    UVSourceCxx, VertexShaderIDEnumCxx, VertextShaderIDCxx,
};

impl From<ClipFlags> for ClipFlagsCxx {
    fn from(value: ClipFlags) -> Self {
        Self {
            value: value.value,
            res: value.res.into(),
        }
    }
}

impl From<ClipFlagsEnum> for ClipFlagsEnumCxx {
    fn from(value: ClipFlagsEnum) -> Self {
        match value {
            ClipFlagsEnum::ClipNoneNormal => ClipFlagsEnumCxx::ClipNoneNormal,
            ClipFlagsEnum::ClipFront => ClipFlagsEnumCxx::ClipFront,
            ClipFlagsEnum::ClipBack => ClipFlagsEnumCxx::ClipBack,
            ClipFlagsEnum::ClipLeft => ClipFlagsEnumCxx::ClipLeft,
            ClipFlagsEnum::ClipRight => ClipFlagsEnumCxx::ClipRight,
            ClipFlagsEnum::ClipBottom => ClipFlagsEnumCxx::ClipBottom,
            ClipFlagsEnum::ClipTop => ClipFlagsEnumCxx::ClipTop,
            ClipFlagsEnum::ClipUser0 => ClipFlagsEnumCxx::ClipUser0,
            ClipFlagsEnum::ClipAll => ClipFlagsEnumCxx::ClipAll,
            ClipFlagsEnum::ClipLandMask => ClipFlagsEnumCxx::ClipLandMask,
            ClipFlagsEnum::ClipLandStep => ClipFlagsEnumCxx::ClipLandStep,
            ClipFlagsEnum::ClipLandUnder => ClipFlagsEnumCxx::ClipLandUnder,
            ClipFlagsEnum::ClipLandAbove => ClipFlagsEnumCxx::ClipLandAbove,
            ClipFlagsEnum::ClipLandKeep => ClipFlagsEnumCxx::ClipLandKeep,
            ClipFlagsEnum::ClipDecalMask => ClipFlagsEnumCxx::ClipDecalMask,
            ClipFlagsEnum::ClipDecalStep => ClipFlagsEnumCxx::ClipDecalStep,
            ClipFlagsEnum::ClipDecalVertical => ClipFlagsEnumCxx::ClipDecalVertical,
            ClipFlagsEnum::ClipFogMask => ClipFlagsEnumCxx::ClipFogMask,
            ClipFlagsEnum::ClipFogStep => ClipFlagsEnumCxx::ClipFogStep,
            ClipFlagsEnum::ClipFogSky => ClipFlagsEnumCxx::ClipFogSky,
            ClipFlagsEnum::ClipLightMask => ClipFlagsEnumCxx::ClipLightMask,
            ClipFlagsEnum::ClipLightStep => ClipFlagsEnumCxx::ClipLightStep,
            ClipFlagsEnum::ClipLightLine => ClipFlagsEnumCxx::ClipLightLine,
            ClipFlagsEnum::ClipUserMask => ClipFlagsEnumCxx::ClipUserMask,
            ClipFlagsEnum::ClipUserStep => ClipFlagsEnumCxx::ClipUserStep,
            ClipFlagsEnum::MaxUserValue => ClipFlagsEnumCxx::MaxUserValue,
            ClipFlagsEnum::ClipHints => ClipFlagsEnumCxx::ClipHints,
            _ => ClipFlagsEnumCxx::Unknown,
        }
    }
}

impl From<PixelShaderID> for PixelShaderIDCxx {
    fn from(value: PixelShaderID) -> Self {
        match value {
            PixelShaderID::PSNormal => PixelShaderIDCxx::PSNormal,
            PixelShaderID::PSNormalDXTA => PixelShaderIDCxx::PSNormalDXTA,
            PixelShaderID::PSNormalMap => PixelShaderIDCxx::PSNormalMap,
            PixelShaderID::PSNormalMapThrough => PixelShaderIDCxx::PSNormalMapThrough,
            PixelShaderID::PSNormalMapGrass => PixelShaderIDCxx::PSNormalMapGrass,
            PixelShaderID::PSNormalMapDiffuse => PixelShaderIDCxx::PSNormalMapDiffuse,
            PixelShaderID::PSDetail => PixelShaderIDCxx::PSDetail,
            PixelShaderID::PSInterpolation => PixelShaderIDCxx::PSInterpolation,
            PixelShaderID::PSWater => PixelShaderIDCxx::PSWater,
            PixelShaderID::PSWaterSimple => PixelShaderIDCxx::PSWaterSimple,
            PixelShaderID::PSWhite => PixelShaderIDCxx::PSWhite,
            PixelShaderID::PSWhiteAlpha => PixelShaderIDCxx::PSWhiteAlpha,
            PixelShaderID::PSAlphaShadow => PixelShaderIDCxx::PSAlphaShadow,
            PixelShaderID::PSAlphaNoShadow => PixelShaderIDCxx::PSAlphaNoShadow,
            PixelShaderID::PSDummy0 => PixelShaderIDCxx::PSDummy0,
            PixelShaderID::PSDetailMacroAS => PixelShaderIDCxx::PSDetailMacroAS,
            PixelShaderID::PSNormalMapMacroAS => PixelShaderIDCxx::PSNormalMapMacroAS,
            PixelShaderID::PSNormalMapDiffuseMacroAS => PixelShaderIDCxx::PSNormalMapDiffuseMacroAS,
            PixelShaderID::PSNormalMapSpecularMap => PixelShaderIDCxx::PSNormalMapSpecularMap,
            PixelShaderID::PSNormalMapDetailSpecularMap => {
                PixelShaderIDCxx::PSNormalMapDetailSpecularMap
            }
            PixelShaderID::PSNormalMapMacroASSpecularMap => {
                PixelShaderIDCxx::PSNormalMapMacroASSpecularMap
            }
            PixelShaderID::PSNormalMapDetailMacroASSpecularMap => {
                PixelShaderIDCxx::PSNormalMapDetailMacroASSpecularMap
            }
            PixelShaderID::PSNormalMapSpecularDIMap => PixelShaderIDCxx::PSNormalMapSpecularDIMap,
            PixelShaderID::PSNormalMapDetailSpecularDIMap => {
                PixelShaderIDCxx::PSNormalMapDetailSpecularDIMap
            }
            PixelShaderID::PSNormalMapMacroASSpecularDIMap => {
                PixelShaderIDCxx::PSNormalMapMacroASSpecularDIMap
            }
            PixelShaderID::PSNormalMapDetailMacroASSpecularDIMap => {
                PixelShaderIDCxx::PSNormalMapDetailMacroASSpecularDIMap
            }
            PixelShaderID::PSTerrain1 => PixelShaderIDCxx::PSTerrain1,
            PixelShaderID::PSTerrain2 => PixelShaderIDCxx::PSTerrain2,
            PixelShaderID::PSTerrain3 => PixelShaderIDCxx::PSTerrain3,
            PixelShaderID::PSTerrain4 => PixelShaderIDCxx::PSTerrain4,
            PixelShaderID::PSTerrain5 => PixelShaderIDCxx::PSTerrain5,
            PixelShaderID::PSTerrain6 => PixelShaderIDCxx::PSTerrain6,
            PixelShaderID::PSTerrain7 => PixelShaderIDCxx::PSTerrain7,
            PixelShaderID::PSTerrain8 => PixelShaderIDCxx::PSTerrain8,
            PixelShaderID::PSTerrain9 => PixelShaderIDCxx::PSTerrain9,
            PixelShaderID::PSTerrain10 => PixelShaderIDCxx::PSTerrain10,
            PixelShaderID::PSTerrain11 => PixelShaderIDCxx::PSTerrain11,
            PixelShaderID::PSTerrain12 => PixelShaderIDCxx::PSTerrain12,
            PixelShaderID::PSTerrain13 => PixelShaderIDCxx::PSTerrain13,
            PixelShaderID::PSTerrain14 => PixelShaderIDCxx::PSTerrain14,
            PixelShaderID::PSTerrain15 => PixelShaderIDCxx::PSTerrain15,
            PixelShaderID::PSTerrainSimple1 => PixelShaderIDCxx::PSTerrainSimple1,
            PixelShaderID::PSTerrainSimple2 => PixelShaderIDCxx::PSTerrainSimple2,
            PixelShaderID::PSTerrainSimple3 => PixelShaderIDCxx::PSTerrainSimple3,
            PixelShaderID::PSTerrainSimple4 => PixelShaderIDCxx::PSTerrainSimple4,
            PixelShaderID::PSTerrainSimple5 => PixelShaderIDCxx::PSTerrainSimple5,
            PixelShaderID::PSTerrainSimple6 => PixelShaderIDCxx::PSTerrainSimple6,
            PixelShaderID::PSTerrainSimple7 => PixelShaderIDCxx::PSTerrainSimple7,
            PixelShaderID::PSTerrainSimple8 => PixelShaderIDCxx::PSTerrainSimple8,
            PixelShaderID::PSTerrainSimple9 => PixelShaderIDCxx::PSTerrainSimple9,
            PixelShaderID::PSTerrainSimple10 => PixelShaderIDCxx::PSTerrainSimple10,
            PixelShaderID::PSTerrainSimple11 => PixelShaderIDCxx::PSTerrainSimple11,
            PixelShaderID::PSTerrainSimple12 => PixelShaderIDCxx::PSTerrainSimple12,
            PixelShaderID::PSTerrainSimple13 => PixelShaderIDCxx::PSTerrainSimple13,
            PixelShaderID::PSTerrainSimple14 => PixelShaderIDCxx::PSTerrainSimple14,
            PixelShaderID::PSTerrainSimple15 => PixelShaderIDCxx::PSTerrainSimple15,
            PixelShaderID::PSGlass => PixelShaderIDCxx::PSGlass,
            PixelShaderID::PSNonTL => PixelShaderIDCxx::PSNonTL,
            PixelShaderID::PSNormalMapSpecularThrough => {
                PixelShaderIDCxx::PSNormalMapSpecularThrough
            }
            PixelShaderID::PSGrass => PixelShaderIDCxx::PSGrass,
            PixelShaderID::PSNormalMapThroughSimple => PixelShaderIDCxx::PSNormalMapThroughSimple,
            PixelShaderID::PSNormalMapSpecularThroughSimple => {
                PixelShaderIDCxx::PSNormalMapSpecularThroughSimple
            }
            PixelShaderID::PSRoad => PixelShaderIDCxx::PSRoad,
            PixelShaderID::PSShore => PixelShaderIDCxx::PSShore,
            PixelShaderID::PSShoreWet => PixelShaderIDCxx::PSShoreWet,
            PixelShaderID::PSRoad2Pass => PixelShaderIDCxx::PSRoad2Pass,
            PixelShaderID::PSShoreFoam => PixelShaderIDCxx::PSShoreFoam,
            PixelShaderID::PSNonTLFlare => PixelShaderIDCxx::PSNonTLFlare,
            PixelShaderID::PSNormalMapThroughLowEnd => PixelShaderIDCxx::PSNormalMapThroughLowEnd,
            PixelShaderID::PSTerrainGrass1 => PixelShaderIDCxx::PSTerrainGrass1,
            PixelShaderID::PSTerrainGrass2 => PixelShaderIDCxx::PSTerrainGrass2,
            PixelShaderID::PSTerrainGrass3 => PixelShaderIDCxx::PSTerrainGrass3,
            PixelShaderID::PSTerrainGrass4 => PixelShaderIDCxx::PSTerrainGrass4,
            PixelShaderID::PSTerrainGrass5 => PixelShaderIDCxx::PSTerrainGrass5,
            PixelShaderID::PSTerrainGrass6 => PixelShaderIDCxx::PSTerrainGrass6,
            PixelShaderID::PSTerrainGrass7 => PixelShaderIDCxx::PSTerrainGrass7,
            PixelShaderID::PSTerrainGrass8 => PixelShaderIDCxx::PSTerrainGrass8,
            PixelShaderID::PSTerrainGrass9 => PixelShaderIDCxx::PSTerrainGrass9,
            PixelShaderID::PSTerrainGrass10 => PixelShaderIDCxx::PSTerrainGrass10,
            PixelShaderID::PSTerrainGrass11 => PixelShaderIDCxx::PSTerrainGrass11,
            PixelShaderID::PSTerrainGrass12 => PixelShaderIDCxx::PSTerrainGrass12,
            PixelShaderID::PSTerrainGrass13 => PixelShaderIDCxx::PSTerrainGrass13,
            PixelShaderID::PSTerrainGrass14 => PixelShaderIDCxx::PSTerrainGrass14,
            PixelShaderID::PSTerrainGrass15 => PixelShaderIDCxx::PSTerrainGrass15,
            PixelShaderID::PSCrater1 => PixelShaderIDCxx::PSCrater1,
            PixelShaderID::PSCrater2 => PixelShaderIDCxx::PSCrater2,
            PixelShaderID::PSCrater3 => PixelShaderIDCxx::PSCrater3,
            PixelShaderID::PSCrater4 => PixelShaderIDCxx::PSCrater4,
            PixelShaderID::PSCrater5 => PixelShaderIDCxx::PSCrater5,
            PixelShaderID::PSCrater6 => PixelShaderIDCxx::PSCrater6,
            PixelShaderID::PSCrater7 => PixelShaderIDCxx::PSCrater7,
            PixelShaderID::PSCrater8 => PixelShaderIDCxx::PSCrater8,
            PixelShaderID::PSCrater9 => PixelShaderIDCxx::PSCrater9,
            PixelShaderID::PSCrater10 => PixelShaderIDCxx::PSCrater10,
            PixelShaderID::PSCrater11 => PixelShaderIDCxx::PSCrater11,
            PixelShaderID::PSCrater12 => PixelShaderIDCxx::PSCrater12,
            PixelShaderID::PSCrater13 => PixelShaderIDCxx::PSCrater13,
            PixelShaderID::PSCrater14 => PixelShaderIDCxx::PSCrater14,
            PixelShaderID::PSSprite => PixelShaderIDCxx::PSSprite,
            PixelShaderID::PSSpriteSimple => PixelShaderIDCxx::PSSpriteSimple,
            PixelShaderID::PSCloud => PixelShaderIDCxx::PSCloud,
            PixelShaderID::PSHorizon => PixelShaderIDCxx::PSHorizon,
            PixelShaderID::PSSuper => PixelShaderIDCxx::PSSuper,
            PixelShaderID::PSMulti => PixelShaderIDCxx::PSMulti,
            PixelShaderID::PSTerrainX => PixelShaderIDCxx::PSTerrainX,
            PixelShaderID::PSTerrainSimpleX => PixelShaderIDCxx::PSTerrainSimpleX,
            PixelShaderID::PSTerrainGrassX => PixelShaderIDCxx::PSTerrainGrassX,
            PixelShaderID::PSTree => PixelShaderIDCxx::PSTree,
            PixelShaderID::PSTreePRT => PixelShaderIDCxx::PSTreePRT,
            PixelShaderID::PSTreeSimple => PixelShaderIDCxx::PSTreeSimple,
            PixelShaderID::PSSkin => PixelShaderIDCxx::PSSkin,
            PixelShaderID::PSCalmWater => PixelShaderIDCxx::PSCalmWater,
            PixelShaderID::PSTreeAToC => PixelShaderIDCxx::PSTreeAToC,
            PixelShaderID::PSGrassAToC => PixelShaderIDCxx::PSGrassAToC,
            PixelShaderID::PSTreeAdv => PixelShaderIDCxx::PSTreeAdv,
            PixelShaderID::PSTreeAdvSimple => PixelShaderIDCxx::PSTreeAdvSimple,
            PixelShaderID::PSTreeAdvTrunk => PixelShaderIDCxx::PSTreeAdvSimple,
            PixelShaderID::PSTreeAdvTrunkSimple => PixelShaderIDCxx::PSTreeAdvTrunkSimple,
            PixelShaderID::PSTreeAdvAToC => PixelShaderIDCxx::PSTreeAdvAToC,
            PixelShaderID::PSTreeAdvSimpleAToC => PixelShaderIDCxx::PSTreeAdvSimpleAToC,
            PixelShaderID::PSTreeSN => PixelShaderIDCxx::PSTreeSN,
            PixelShaderID::PSSpriteExtTi => PixelShaderIDCxx::PSSpriteExtTi,
            PixelShaderID::PSTerrainSNX => PixelShaderIDCxx::PSTerrainSNX,
            PixelShaderID::PSSimulWeatherClouds => PixelShaderIDCxx::PSSimulWeatherClouds,
            PixelShaderID::PSSimulWeatherCloudsWithLightning => {
                PixelShaderIDCxx::PSSimulWeatherCloudsWithLightning
            }
            PixelShaderID::PSSimulWeatherCloudsCPU => PixelShaderIDCxx::PSSimulWeatherCloudsCPU,
            PixelShaderID::PSSimulWeatherCloudsWithLightningCPU => {
                PixelShaderIDCxx::PSSimulWeatherCloudsWithLightningCPU
            }
            PixelShaderID::PSSuperExt => PixelShaderIDCxx::PSSuperExt,
            PixelShaderID::PSSuperAToC => PixelShaderIDCxx::PSSuperAToC,
            PixelShaderID::NPixelShaderID => PixelShaderIDCxx::NPixelShaderID,
            PixelShaderID::PSUninitialized => PixelShaderIDCxx::PSUninitialized,
        }
    }
}

impl From<VertexShaderID> for VertextShaderIDCxx {
    fn from(value: VertexShaderID) -> Self {
        Self {
            v: value.value,
            e: value.e.into(),
        }
    }
}

impl From<VertexShaderIDEnum> for VertexShaderIDEnumCxx {
    fn from(value: VertexShaderIDEnum) -> Self {
        match value {
            VertexShaderIDEnum::VSBasic => VertexShaderIDEnumCxx::VSBasic,
            VertexShaderIDEnum::VSNormalMap => VertexShaderIDEnumCxx::VSNormalMap,
            VertexShaderIDEnum::VSNormalMapDiffuse => VertexShaderIDEnumCxx::VSNormalMapDiffuse,
            VertexShaderIDEnum::VSGrass => VertexShaderIDEnumCxx::VSGrass,
            VertexShaderIDEnum::VSDummy1 => VertexShaderIDEnumCxx::VSDummy1,
            VertexShaderIDEnum::VSDummy2 => VertexShaderIDEnumCxx::VSDummy2,
            VertexShaderIDEnum::VSShadowVolume => VertexShaderIDEnumCxx::VSShadowVolume,
            VertexShaderIDEnum::VSWater => VertexShaderIDEnumCxx::VSWater,
            VertexShaderIDEnum::VSWaterSimple => VertexShaderIDEnumCxx::VSWaterSimple,
            VertexShaderIDEnum::VSSprite => VertexShaderIDEnumCxx::VSSprite,
            VertexShaderIDEnum::VSPoint => VertexShaderIDEnumCxx::VSPoint,
            VertexShaderIDEnum::VSNormalMapThrough => VertexShaderIDEnumCxx::VSNormalMapThrough,
            VertexShaderIDEnum::VSDummy3 => VertexShaderIDEnumCxx::VSDummy3,
            VertexShaderIDEnum::VSTerrain => VertexShaderIDEnumCxx::VSTerrain,
            VertexShaderIDEnum::VSBasicAS => VertexShaderIDEnumCxx::VSBasicAS,
            VertexShaderIDEnum::VSNormalMapAS => VertexShaderIDEnumCxx::VSNormalMapAS,
            VertexShaderIDEnum::VSNormalMapDiffuseAS => VertexShaderIDEnumCxx::VSNormalMapDiffuseAS,
            VertexShaderIDEnum::VSGlass => VertexShaderIDEnumCxx::VSGlass,
            VertexShaderIDEnum::VSNormalMapSpecularThrough => {
                VertexShaderIDEnumCxx::VSNormalMapSpecularThrough
            }
            VertexShaderIDEnum::VSNormalMapThroughNoFade => {
                VertexShaderIDEnumCxx::VSNormalMapThroughNoFade
            }
            VertexShaderIDEnum::VSNormalMapSpecularThroughNoFade => {
                VertexShaderIDEnumCxx::VSNormalMapSpecularThroughNoFade
            }
            VertexShaderIDEnum::VSShore => VertexShaderIDEnumCxx::VSShore,
            VertexShaderIDEnum::VSTerrainGrass => VertexShaderIDEnumCxx::VSTerrainGrass,
            VertexShaderIDEnum::VSSuper => VertexShaderIDEnumCxx::VSSuper,
            VertexShaderIDEnum::VSMulti => VertexShaderIDEnumCxx::VSMulti,
            VertexShaderIDEnum::VSTree => VertexShaderIDEnumCxx::VSTree,
            VertexShaderIDEnum::VSTreeNoFade => VertexShaderIDEnumCxx::VSTreeNoFade,
            VertexShaderIDEnum::VSTreePRT => VertexShaderIDEnumCxx::VSTreePRT,
            VertexShaderIDEnum::VSTreePRTNoFade => VertexShaderIDEnumCxx::VSTreePRTNoFade,
            VertexShaderIDEnum::VSSkin => VertexShaderIDEnumCxx::VSSkin,
            VertexShaderIDEnum::VSCalmWater => VertexShaderIDEnumCxx::VSCalmWater,
            VertexShaderIDEnum::VSTreeAdv => VertexShaderIDEnumCxx::VSTreeAdv,
            VertexShaderIDEnum::VSTreeAdvTrunk => VertexShaderIDEnumCxx::VSTreeAdvTrunk,
            VertexShaderIDEnum::VSSimulWeatherClouds => VertexShaderIDEnumCxx::VSSimulWeatherClouds,
            VertexShaderIDEnum::VSSimulWeatherCloudsCPU => {
                VertexShaderIDEnumCxx::VSSimulWeatherCloudsCPU
            }
            VertexShaderIDEnum::NVertexShaderID => VertexShaderIDEnumCxx::NVertexShaderID,
            _ => VertexShaderIDEnumCxx::Unknown,
        }
    }
}

impl From<EMainLight> for EMainLightCxx {
    fn from(value: EMainLight) -> Self {
        match value {
            EMainLight::None => EMainLightCxx::None,
            EMainLight::Sun => EMainLightCxx::Sun,
            EMainLight::Sky => EMainLightCxx::Sky,
            EMainLight::Horizon => EMainLightCxx::Horizon,
            EMainLight::Stars => EMainLightCxx::Stars,
            EMainLight::SunObject => EMainLightCxx::SunObject,
            EMainLight::SunHaloObject => EMainLightCxx::SunHaloObject,
            EMainLight::MoonObject => EMainLightCxx::MoonObject,
            EMainLight::MoonHaloObject => EMainLightCxx::MoonHaloObject,
        }
    }
}

impl From<TextureFilterType> for TextureFilterTypeCxx {
    fn from(value: TextureFilterType) -> Self {
        match value {
            TextureFilterType::Point => TextureFilterTypeCxx::Point,
            TextureFilterType::Linear => TextureFilterTypeCxx::Linear,
            TextureFilterType::Triliniear => TextureFilterTypeCxx::Triliniear,
            TextureFilterType::Anisotropic => TextureFilterTypeCxx::Anisotropic,
        }
    }
}
impl From<UVSource> for UVSourceCxx {
    fn from(value: UVSource) -> Self {
        match value {
            UVSource::UVNone => UVSourceCxx::UVNone,
            UVSource::UVTex => UVSourceCxx::UVTex,
            UVSource::UVTexWaterAnim => UVSourceCxx::UVTexWaterAnim,
            UVSource::UVPos => UVSourceCxx::UVPos,
            UVSource::UVNorm => UVSourceCxx::UVNorm,
            UVSource::UVTex1 => UVSourceCxx::UVTex1,
            UVSource::UVWorldPos => UVSourceCxx::UVWorldPos,
            UVSource::UVWorldNorm => UVSourceCxx::UVWorldNorm,
            UVSource::UVTexShoreAnim => UVSourceCxx::UVTexShoreAnim,
            UVSource::NUVSource => UVSourceCxx::NUVSource,
        }
    }
}
impl From<AnimAddress> for AnimAddressCxx {
    fn from(value: AnimAddress) -> Self {
        match value {
            AnimAddress::AnimClamp => AnimAddressCxx::AnimClamp,
            AnimAddress::AnimLoop => AnimAddressCxx::AnimLoop,
            AnimAddress::AnimMirror => AnimAddressCxx::AnimMirror,
            AnimAddress::NAnimAddress => AnimAddressCxx::NAnimAddress,
        }
    }
}

impl From<AnimType> for AnimTypeCxx {
    fn from(value: AnimType) -> Self {
        match value {
            AnimType::Rotation => AnimTypeCxx::Rotation,
            AnimType::RotationX => AnimTypeCxx::RotationX,
            AnimType::RotationY => AnimTypeCxx::RotationY,
            AnimType::RotationZ => AnimTypeCxx::RotationZ,
            AnimType::Translation => AnimTypeCxx::Translation,
            AnimType::TranslationX => AnimTypeCxx::TranslationX,
            AnimType::TranslationY => AnimTypeCxx::TranslationY,
            AnimType::TranslationZ => AnimTypeCxx::TranslationZ,
            AnimType::Direct => AnimTypeCxx::Direct,
            AnimType::Hide => AnimTypeCxx::Hide,
        }
    }
}

impl From<MapType> for MapTypeCxx {
    fn from(value: MapType) -> Self {
        match value {
            MapType::MapTree => MapTypeCxx::MapTree,
            MapType::MapSmallTree => MapTypeCxx::MapSmallTree,
            MapType::MapBush => MapTypeCxx::MapBush,
            MapType::MapBuilding => MapTypeCxx::MapBuilding,
            MapType::MapHouse => MapTypeCxx::MapHouse,
            MapType::MapForestBorder => MapTypeCxx::MapForestBorder,
            MapType::MapForestTriangle => MapTypeCxx::MapForestTriangle,
            MapType::MapForestSquare => MapTypeCxx::MapForestSquare,
            MapType::MapChurch => MapTypeCxx::MapChurch,
            MapType::MapChapel => MapTypeCxx::MapChapel,
            MapType::MapCross => MapTypeCxx::MapCross,
            MapType::MapRock => MapTypeCxx::MapRoad,
            MapType::MapBunker => MapTypeCxx::MapBunker,
            MapType::MapFortress => MapTypeCxx::MapForest,
            MapType::MapFountain => MapTypeCxx::MapFountain,
            MapType::MapViewTower => MapTypeCxx::MapViewTower,
            MapType::MapLighthouse => MapTypeCxx::MapLighthouse,
            MapType::MapQuay => MapTypeCxx::MapQuay,
            MapType::MapFuelstation => MapTypeCxx::MapFuelstation,
            MapType::MapHospital => MapTypeCxx::MapHospital,
            MapType::MapFence => MapTypeCxx::MapFence,
            MapType::MapWall => MapTypeCxx::MapWall,
            MapType::MapHide => MapTypeCxx::MapHide,
            MapType::MapBusStop => MapTypeCxx::MapBusStop,
            MapType::MapRoad => MapTypeCxx::MapRoad,
            MapType::MapForest => MapTypeCxx::MapForest,
            MapType::MapTransmitter => MapTypeCxx::MapTransmitter,
            MapType::MapStack => MapTypeCxx::MapStack,
            MapType::MapRuin => MapTypeCxx::MapRuin,
            MapType::MapTourism => MapTypeCxx::MapTourism,
            MapType::MapWatertower => MapTypeCxx::MapWatertower,
            MapType::MapTrack => MapTypeCxx::MapTrack,
            MapType::MapMainRoad => MapTypeCxx::MapMainRoad,
            MapType::MapRocks => MapTypeCxx::MapRocks,
            MapType::MapPowerLines => MapTypeCxx::MapPowerLines,
            MapType::MapRailWay => MapTypeCxx::MapRailWay,
            MapType::NMapTypes => MapTypeCxx::NMapTypes,
        }
    }
}
impl From<SBSource> for SBSourceCxx {
    fn from(value: SBSource) -> Self {
        match value {
            SBSource::Visual => SBSourceCxx::Visual,
            SBSource::ShadowVolume => SBSourceCxx::ShadowVolume,
            SBSource::Explicit => SBSourceCxx::Explicit,
            SBSource::None => SBSourceCxx::None,
            SBSource::VisualEx => SBSourceCxx::VisualEx,
        }
    }
}
impl From<ResolutionEnum> for ResolutionEnumCxx {
    fn from(value: ResolutionEnum) -> Self {
        match value {
            ResolutionEnum::GraphicalLod => ResolutionEnumCxx::GraphicalLod,
            ResolutionEnum::ViewGunner => ResolutionEnumCxx::ViewGunner,
            ResolutionEnum::ViewPilot => ResolutionEnumCxx::ViewPilot,
            ResolutionEnum::ViewCargo => ResolutionEnumCxx::ViewCargo,
            ResolutionEnum::ViewUnknown => ResolutionEnumCxx::ViewUnknown,
            ResolutionEnum::ShadowVolume => ResolutionEnumCxx::ShadowVolume,
            ResolutionEnum::ShadowVolume2 => ResolutionEnumCxx::ShadowVolume2,
            ResolutionEnum::StencilShadow => ResolutionEnumCxx::StencilShadow,
            ResolutionEnum::StencilShadow2 => ResolutionEnumCxx::StencilShadow2,
            ResolutionEnum::StencilShadowUnknown => ResolutionEnumCxx::StencilShadowUnknown,
            ResolutionEnum::Geometry => ResolutionEnumCxx::Geometry,
            ResolutionEnum::Unknown4E13 => ResolutionEnumCxx::Unknown4E13,
            ResolutionEnum::Memory => ResolutionEnumCxx::Memory,
            ResolutionEnum::LandContact => ResolutionEnumCxx::LandContact,
            ResolutionEnum::Roadway => ResolutionEnumCxx::Roadway,
            ResolutionEnum::Paths => ResolutionEnumCxx::Paths,
            ResolutionEnum::HitPoints => ResolutionEnumCxx::HitPoints,
            ResolutionEnum::ViewGeometry => ResolutionEnumCxx::ViewGeometry,
            ResolutionEnum::FireGeometry => ResolutionEnumCxx::FireGeometry,
            ResolutionEnum::ViewCargoGeometry => ResolutionEnumCxx::ViewCargoGeometry,
            ResolutionEnum::ViewCargoFireGeometry => ResolutionEnumCxx::ViewCargoFireGeometry,
            ResolutionEnum::ViewCommander => ResolutionEnumCxx::ViewCommander,
            ResolutionEnum::ViewCommanderGeometry => ResolutionEnumCxx::ViewCommanderGeometry,
            ResolutionEnum::ViewCommanderFireGeometry => {
                ResolutionEnumCxx::ViewCommanderFireGeometry
            }
            ResolutionEnum::ViewPilotGeometry => ResolutionEnumCxx::ViewPilotGeometry,
            ResolutionEnum::ViewPilotFireGeometry => ResolutionEnumCxx::ViewPilotFireGeometry,
            ResolutionEnum::ViewGunnerGeometry => ResolutionEnumCxx::ViewGunnerGeometry,
            ResolutionEnum::ViewGunnerFireGeometry => ResolutionEnumCxx::ViewGunnerFireGeometry,
            ResolutionEnum::SubParts => ResolutionEnumCxx::SubParts,
            ResolutionEnum::ShadowVolumeViewCargo => ResolutionEnumCxx::ShadowVolumeViewCargo,
            ResolutionEnum::ShadowVolumeViewPilot => ResolutionEnumCxx::ShadowVolumeViewPilot,
            ResolutionEnum::ShadowVolumeViewGunner => ResolutionEnumCxx::ShadowVolumeViewGunner,
            ResolutionEnum::Wreck => ResolutionEnumCxx::Wreck,
            ResolutionEnum::Unknown(_) => ResolutionEnumCxx::Unknown,
        }
    }
}

impl From<EFogMode> for EFogModeCxx {
    fn from(value: EFogMode) -> Self {
        match value {
            EFogMode::None => EFogModeCxx::None,
            EFogMode::Fog => EFogModeCxx::Fog,
            EFogMode::Alpha => EFogModeCxx::Alpha,
            EFogMode::FogAlpha => EFogModeCxx::FogAlpha,
        }
    }
}

impl From<ResolutionEnumCxx> for ResolutionEnum {
    fn from(value: ResolutionEnumCxx) -> Self {
        match value {
            ResolutionEnumCxx::GraphicalLod => ResolutionEnum::GraphicalLod,
            ResolutionEnumCxx::ViewGunner => ResolutionEnum::ViewGunner,
            ResolutionEnumCxx::ViewPilot => ResolutionEnum::ViewPilot,
            ResolutionEnumCxx::ViewCargo => ResolutionEnum::ViewCargo,
            ResolutionEnumCxx::ViewUnknown => ResolutionEnum::ViewUnknown,
            ResolutionEnumCxx::ShadowVolume => ResolutionEnum::ShadowVolume,
            ResolutionEnumCxx::ShadowVolume2 => ResolutionEnum::ShadowVolume2,
            ResolutionEnumCxx::StencilShadow => ResolutionEnum::StencilShadow,
            ResolutionEnumCxx::StencilShadow2 => ResolutionEnum::StencilShadow2,
            ResolutionEnumCxx::StencilShadowUnknown => ResolutionEnum::StencilShadowUnknown,
            ResolutionEnumCxx::Geometry => ResolutionEnum::Geometry,
            ResolutionEnumCxx::Unknown4E13 => ResolutionEnum::Unknown4E13,
            ResolutionEnumCxx::Memory => ResolutionEnum::Memory,
            ResolutionEnumCxx::LandContact => ResolutionEnum::LandContact,
            ResolutionEnumCxx::Roadway => ResolutionEnum::Roadway,
            ResolutionEnumCxx::Paths => ResolutionEnum::Paths,
            ResolutionEnumCxx::HitPoints => ResolutionEnum::HitPoints,
            ResolutionEnumCxx::ViewGeometry => ResolutionEnum::ViewGeometry,
            ResolutionEnumCxx::FireGeometry => ResolutionEnum::FireGeometry,
            ResolutionEnumCxx::ViewCargoGeometry => ResolutionEnum::ViewCargoGeometry,
            ResolutionEnumCxx::ViewCargoFireGeometry => ResolutionEnum::ViewCargoFireGeometry,
            ResolutionEnumCxx::ViewCommander => ResolutionEnum::ViewCommander,
            ResolutionEnumCxx::ViewCommanderGeometry => ResolutionEnum::ViewCommanderGeometry,
            ResolutionEnumCxx::ViewCommanderFireGeometry => {
                ResolutionEnum::ViewCommanderFireGeometry
            }
            ResolutionEnumCxx::ViewPilotGeometry => ResolutionEnum::ViewPilotGeometry,
            ResolutionEnumCxx::ViewPilotFireGeometry => ResolutionEnum::ViewPilotFireGeometry,
            ResolutionEnumCxx::ViewGunnerGeometry => ResolutionEnum::ViewGunnerGeometry,
            ResolutionEnumCxx::ViewGunnerFireGeometry => ResolutionEnum::ViewGunnerFireGeometry,
            ResolutionEnumCxx::SubParts => ResolutionEnum::SubParts,
            ResolutionEnumCxx::ShadowVolumeViewCargo => ResolutionEnum::ShadowVolumeViewCargo,
            ResolutionEnumCxx::ShadowVolumeViewPilot => ResolutionEnum::ShadowVolumeViewPilot,
            ResolutionEnumCxx::ShadowVolumeViewGunner => ResolutionEnum::ShadowVolumeViewGunner,
            ResolutionEnumCxx::Wreck => ResolutionEnum::Wreck,
            ResolutionEnumCxx::Unknown => ResolutionEnum::Unknown(PhantomData {}),
            ResolutionEnumCxx {
                repr: 34_u8..=u8::MAX,
            } => ResolutionEnum::Unknown(PhantomData {}),
        }
    }
}

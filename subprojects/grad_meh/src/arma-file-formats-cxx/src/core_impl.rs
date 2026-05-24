use arma_file_formats::real_virtuality::types::{
    BoundingBox, D3DColorValue, RGBAColor, TransformMatrix, XY, XYZTriplet,
};

use crate::bridge::{
    BoundingBoxCxx, D3DColorValueCxx, RGBAColorCxx, TransformMatrixCxx, XYCxx, XYZTripletCxx,
};

impl From<TransformMatrix> for TransformMatrixCxx {
    fn from(value: TransformMatrix) -> Self {
        Self {
            _0: value.0.into(),
            _1: value.1.into(),
            _2: value.2.into(),
            _3: value.3.into(),
        }
    }
}

impl From<XYZTriplet> for XYZTripletCxx {
    fn from(value: XYZTriplet) -> Self {
        Self {
            x: value.x,
            y: value.y,
            z: value.z,
        }
    }
}

impl From<BoundingBox> for BoundingBoxCxx {
    fn from(value: BoundingBox) -> Self {
        Self {
            a: value.a.into(),
            b: value.b.into(),
            c: value.c.into(),
            d: value.d.into(),
        }
    }
}

impl From<XY> for XYCxx {
    fn from(value: XY) -> Self {
        Self {
            x: value.x,
            y: value.y,
        }
    }
}
impl From<D3DColorValue> for D3DColorValueCxx {
    fn from(v: D3DColorValue) -> Self {
        Self {
            r: v.r,
            g: v.g,
            b: v.b,
            a: v.a,
        }
    }
}
impl From<RGBAColor> for RGBAColorCxx {
    fn from(v: RGBAColor) -> Self {
        Self {
            a: v.a,
            b: v.b,
            c: v.c,
            d: v.d,
        }
    }
}

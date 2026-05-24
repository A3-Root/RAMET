use arma_file_formats::real_virtuality::pbo::{Entry, Pbo};

use crate::bridge::{EntryCxx, PboCxx, PboPropertyCxx};

impl From<Entry> for EntryCxx {
    fn from(entry: Entry) -> Self {
        Self {
            filename: entry.filename,
            mime_type: entry.mime_type,
            size: entry.original_size,
            timestamp: entry.timestamp,
            data: entry.data,
        }
    }
}

impl From<Pbo> for PboCxx {
    fn from(pbo: Pbo) -> Self {
        Self {
            properties: pbo
                .properties
                .into_iter()
                .map(|(key, value)| PboPropertyCxx { key, value })
                .collect(),
            entries: pbo.entries.into_iter().map(|(_, e)| e.into()).collect(),
            hash: pbo.hash,
        }
    }
}

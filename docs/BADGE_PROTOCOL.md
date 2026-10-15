# Electronic badge transport v1

The fifth device page shows up to four persistent JPEG/GIF assets. A short BOOT
press advances the album on release, only on this page; screen taps do not
change images. PWR keeps its power function. Horizontal swipes still change
instrument pages. Images stay on the
phone/device and are not uploaded to the navigation gateway.

The existing encrypted MOTO GATT service gains RX `7e57a003-b50c-4b6a-9c57-40a54e8e1000`
and notify TX `7e57a004-b50c-4b6a-9c57-40a54e8e1000`. This transfer is independent
of navigation protocol v1. Older phone apps continue navigating without it.

Each request has a 16-byte header: `BG`, version 1, operation, request ID u32le,
slot u8, format u8, payload length u16le, offset u32le. Whole GATT values are at
most 240 bytes; iOS uses at most 182. Replies set operation bit 7, echo the ID
and slot, replace format with status, and carry the committed byte offset.
Reply payload is five bytes: selected slot (255 for none), then each slot's
format (0 empty, 1 baseline JPEG, 2 GIF).

Operations: 1 list; 2 begin (payload total bytes u32le, IEEE CRC32 u32le);
3 chunk (ordered bytes at offset); 4 commit; 5 remove; 6 select (255 = next).
Every command waits for the application-level reply, not merely the GATT write
response. A transfer aborts on disconnect or timeout. Commit requires exact
length, checksum and a bounded image header; the previous asset remains valid
until the file is durable and the NVS catalog commits. Retransmission is not
automatic; a failed transfer starts again with a fresh begin.

Limits: four slots, 512 KiB per encoded file, canvas at most 466 x 466. The
phone resizes/crops stills and GIF frames before transmission. The existing
7 MiB `storage` SPIFFS partition is used; partition offsets do not change.
On first use, an unmountable storage partition is formatted by ESP-IDF SPIFFS;
no flash action has been authorized for the current development iteration.

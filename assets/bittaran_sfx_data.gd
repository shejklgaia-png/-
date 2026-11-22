extends RefCounted
## Four creator-uploaded Bittaran SFX. Vorbis mono/24 kHz for Android.
## Ogg payloads are embedded as base64 to avoid asynchronous source import
## between Termux Git sync and first Godot battle boot.
## Original user MP3 filenames: ロボットの足音1, 巨大ロボットが腕を動かす3,
## 巨大ロボットが倒れる, ロボットを強く殴る3.
const FOOTSTEP: String = "__FOOTSTEP__"
const ARM: String = "__ARM__"
const COLLAPSE: String = "__COLLAPSE__"
const PUNCH: String = "__PUNCH__"

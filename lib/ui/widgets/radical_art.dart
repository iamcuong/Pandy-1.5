import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'common.dart';

/// Hình mô tả cho bộ thủ.
///
/// Ưu tiên ảnh riêng trong `assets/radical_images/NNN.png` (NNN = số bộ, VD 075.png cho 木).
/// Không có ảnh → dùng hình minh hoạ (emoji màu có sẵn trên Android, chạy offline).
/// Bộ trừu tượng không có hình → hiện chữ mờ kèm nghĩa.
class RadicalArt extends StatelessWidget {
  const RadicalArt(this.radical, {super.key, this.size = 112});
  final Radical radical;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = context.select<AppState, String?>((s) => s.radicalImages[radical.id]);
    final fallback = _Fallback(radical: radical, size: size);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: C.pageBg,
          border: Border.all(color: C.borderLight),
          borderRadius: BorderRadius.circular(8),
        ),
        child: path == null
            ? fallback
            : Image.asset(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.radical, required this.size});
  final Radical radical;
  final double size;

  @override
  Widget build(BuildContext context) {
    final emoji = radicalEmoji[radical.id];
    if (emoji != null) {
      return Center(child: Text(emoji, style: TextStyle(fontSize: size * 0.5, height: 1.1)));
    }
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Hz(radical.char, size: size * 0.42, color: C.primary.withValues(alpha: 0.35)),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          radical.meaning,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: ts(size < 80 ? 8 : 10, c: C.ink500),
        ),
      ),
    ]);
  }
}

/// Hình minh hoạ theo số bộ Khang Hi (1..214). Bộ nào không có hình gợi nghĩa rõ thì bỏ trống.
const radicalEmoji = <int, String>{
  1: '1️⃣', 7: '2️⃣', 9: '🧑', 10: '🚶', 11: '📥', 12: '8️⃣', 15: '🧊', 16: '🪑', 18: '🔪', 19: '💪',
  21: '🥄', 22: '🗄️', 24: '🔟', 25: '🔮', 30: '👄', 31: '🔲', 32: '🟫', 33: '🎓', 36: '🌆', 37: '🙆',
  38: '👩', 39: '👶', 40: '🏠', 41: '📐', 42: '🤏', 44: '⚰️', 45: '🌱', 46: '⛰️', 47: '🌊', 48: '🛠️',
  50: '🧣', 53: '🏚️', 55: '🙏', 57: '🏹', 60: '👣', 61: '❤️', 62: '🔱', 63: '🚪', 64: '✋', 67: '🦓',
  68: '🪣', 69: '🪓', 70: '🟦', 71: '🚫', 72: '☀️', 73: '💬', 74: '🌙', 75: '🌳', 76: '🥱', 77: '🛑',
  78: '💀', 80: '⛔', 81: '⚖️', 84: '💨', 85: '💧', 86: '🔥', 87: '🐾', 88: '👨', 90: '🪵', 91: '🧩',
  92: '🦷', 93: '🐂', 94: '🐕', 95: '🌌', 96: '💎', 97: '🍈', 98: '🏯', 99: '🍬', 100: '🐣', 101: '🔧',
  102: '🟩', 104: '🤒', 106: '⚪', 108: '🥣', 109: '👁️', 110: '🗡️', 111: '🎯', 112: '🪨', 113: '⛩️', 114: '👣',
  115: '🌾', 116: '🕳️', 117: '🧍', 118: '🎋', 119: '🍚', 120: '🧵', 121: '🏺', 122: '🥅', 123: '🐐', 124: '🪶',
  125: '👴', 126: '🧔', 127: '🚜', 128: '👂', 129: '🖊️', 130: '🥩', 131: '🙇', 132: '🙋', 133: '🏁', 135: '👅',
  137: '🛶', 139: '🎨', 140: '🌿', 141: '🐯', 142: '🐛', 143: '🩸', 144: '🛣️', 145: '👕', 147: '👀', 148: '📯',
  149: '🗣️', 150: '🏞️', 151: '🫘', 152: '🐖', 153: '🐆', 154: '🐚', 155: '🔴', 156: '🏃', 157: '🦶', 158: '🧘',
  159: '🚗', 160: '🌶️', 161: '✨', 163: '🏘️', 164: '🍶', 166: '🏡', 167: '🥇', 168: '📏', 169: '🏛️', 170: '🏔️',
  172: '🐤', 173: '🌧️', 174: '💚', 175: '❌', 176: '🙂', 177: '🔄', 179: '🥬', 180: '🎵', 181: '📄', 182: '🌬️',
  183: '✈️', 184: '🍽️', 185: '🗿', 186: '🌸', 187: '🐎', 188: '🦴', 189: '🗼', 190: '💇', 191: '🤼', 192: '🍷',
  193: '🍲', 194: '👻', 195: '🐟', 196: '🐦', 197: '🧂', 198: '🦌', 199: '🍞', 201: '🟡', 203: '⚫', 204: '🪡',
  205: '🐸', 207: '🥁', 208: '🐭', 209: '👃', 211: '😁', 212: '🐉', 213: '🐢', 214: '🎶',
};

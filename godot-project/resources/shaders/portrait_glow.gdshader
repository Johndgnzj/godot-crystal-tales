shader_type canvas_item;

// 立繪輪廓背光（rim glow）。對照設定集 codex 的 CSS：
//   filter: drop-shadow(0 0 18px rgba(127,216,234,.30))
// 沿透明 PNG 的輪廓外擴取樣 alpha，取最大化後的柔邊當光暈。用在「立繪副本」上（疊在正片後方），
// 副本本身不畫角色顏色，只輸出 glow_color＋外擴 alpha。
// 使用端：scenes/ui/menu/char_page.gd 的 _build_portrait()。

uniform vec4 glow_color : source_color = vec4(0.498, 0.847, 0.918, 1.0);
uniform float radius = 16.0;      // 外擴距離（貼圖像素）
uniform float intensity = 0.55;   // 光暈強度

void fragment() {
	float a = 0.0;
	for (int i = 0; i < 12; i++) {
		float ang = float(i) * 0.5236;   // 30° × 12 = 一圈
		vec2 d = vec2(cos(ang), sin(ang)) * TEXTURE_PIXEL_SIZE * radius;
		a += texture(TEXTURE, clamp(UV + d, vec2(0.0), vec2(1.0))).a;
		a += texture(TEXTURE, clamp(UV + d * 0.5, vec2(0.0), vec2(1.0))).a;
	}
	a = clamp(a / 24.0 * 2.0, 0.0, 1.0);
	COLOR = vec4(glow_color.rgb, a * intensity);
}

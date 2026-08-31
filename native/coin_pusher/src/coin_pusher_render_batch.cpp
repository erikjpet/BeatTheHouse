#include "coin_pusher_native_core.h"

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <vector>

using namespace godot;

namespace {
constexpr double REAR_WIDTH_FACTOR = 0.78;
constexpr double PLAYFIELD_X = 52.0, PLAYFIELD_Y = 70.0;
constexpr double PLAYFIELD_WIDTH = 796.0, PLAYFIELD_HEIGHT = 276.0;
constexpr double COIN_RY = 12.0, Z_LAYER_OFFSET = 10.0;
constexpr int64_t BATCH_CAPACITY = 600;
constexpr double ROTATIONS[4] = {-0.12, -0.04, 0.04, 0.12};

double clampd(double value, double minimum, double maximum) {
  return std::max(minimum, std::min(maximum, value));
}

double lerpd(double from, double to, double weight) {
  return from + (to - from) * weight;
}

Vector2 project(double x, double y, double z, double world_width,
                double world_back_y, double coin_height) {
  const double depth = clampd(y / world_back_y, 0.0, 1.0);
  const double width_factor = lerpd(1.0, REAR_WIDTH_FACTOR, depth);
  const double center_x = PLAYFIELD_X + PLAYFIELD_WIDTH * 0.5;
  const double screen_x = center_x +
                          (x / world_width - 0.5) * PLAYFIELD_WIDTH * 0.91 *
                              width_factor;
  const double screen_y = PLAYFIELD_Y + PLAYFIELD_HEIGHT - 8.0 -
                          depth * PLAYFIELD_HEIGHT * 0.34 -
                          z / coin_height * Z_LAYER_OFFSET;
  return Vector2(screen_x, screen_y);
}

Vector2 project_board(const Dictionary &board, double x, double z,
                      double world_width, double world_back_y,
                      double coin_height) {
  const double bottom = board.get("z_bottom", 3600.0);
  const double top = std::max(bottom + 1.0,
                              double(board.get("z_top", 24000.0)));
  const double weight = clampd((z - bottom) / (top - bottom), 0.0, 1.0);
  const Vector2 landing = project(x, board.get("y", 78000.0), bottom,
                                  world_width, world_back_y, coin_height);
  return Vector2(landing.x, lerpd(landing.y, PLAYFIELD_Y + COIN_RY + 10.0,
                                  weight));
}
} // namespace

Dictionary CoinPusherNativeCore::build_live_render_batch(
    const Dictionary &config, const Array &current, const Array &previous,
    double alpha) const {
  const int64_t count = std::min<int64_t>(BATCH_CAPACITY, current.size());
  const double safe_alpha = clampd(alpha, 0.0, 1.0);
  const double world_width = std::max(1.0, double(config.get("world_width", 100000.0)));
  const double world_back_y = std::max(1.0, double(config.get("world_back_y", 78000.0)));
  const double coin_height = std::max(1.0, double(config.get("coin_height", 950.0)));
  const double coin_radius = std::max(1.0, double(config.get("coin_radius", 2350.0)));
  const Dictionary board = config.get("board", Dictionary());
  const int64_t board_y = board.get("y", 0);
  const double board_bottom = board.get("z_bottom", 0.0);
  const Dictionary body_colors = config.get("body_colors", Dictionary());
  const Color default_color = Color::from_string(
      String(body_colors.get("default", "#c9c5b8")), Color(0.788, 0.773, 0.722));

  bool aligned = safe_alpha < 0.999 && previous.size() == current.size();
  if (aligned) {
    for (int64_t i = 0; i < current.size(); ++i) {
      Dictionary now = current[i], before = previous[i];
      if (String(now.get("id", "")) != String(before.get("id", ""))) {
        aligned = false;
        break;
      }
    }
  }
  Dictionary previous_by_id;
  if (safe_alpha < 0.999 && !aligned) {
    for (int64_t i = 0; i < previous.size(); ++i) {
      Dictionary body = previous[i];
      previous_by_id[String(body.get("id", ""))] = body;
    }
  }

  std::vector<int64_t> order(size_t(current.size()));
  for (int64_t i = 0; i < current.size(); ++i)
    order[size_t(i)] = i;
  std::sort(order.begin(), order.end(), [&current](int64_t ai, int64_t bi) {
    Dictionary a = current[ai], b = current[bi];
    const int64_t ak = int64_t(a.get("y", 0)) * 100000 - int64_t(a.get("z", 0));
    const int64_t bk = int64_t(b.get("y", 0)) * 100000 - int64_t(b.get("z", 0));
    if (ak != bk)
      return ak > bk;
    return String(a.get("id", "")) < String(b.get("id", ""));
  });

  PackedFloat32Array buffer;
  buffer.resize(count * 12);
  Array shadows, features;
  for (int64_t instance = 0; instance < count; ++instance) {
    const int64_t body_index = order[size_t(instance)];
    Dictionary body = current[body_index];
    const String id = body.get("id", "");
    const String kind = body.get("kind", "coin");
    double x = int64_t(body.get("x", 0));
    double y = int64_t(body.get("y", 0));
    double z = int64_t(body.get("z", 0));
    if (safe_alpha < 0.999) {
      Dictionary prior = aligned ? Dictionary(previous[body_index])
                                 : Dictionary(previous_by_id.get(id, body));
      x = lerpd(int64_t(prior.get("x", body.get("x", 0))), x, safe_alpha);
      y = lerpd(int64_t(prior.get("y", body.get("y", 0))), y, safe_alpha);
      z = lerpd(int64_t(prior.get("z", body.get("z", 0))), z, safe_alpha);
    }
    const bool falling = String(body.get("rest_state", "")) == "falling";
    const bool on_board = falling &&
                          std::abs(int64_t(std::round(y)) - board_y) <=
                              int64_t(body.get("radius", 2350)) &&
                          z >= board_bottom;
    const Vector2 point = on_board
                              ? project_board(board, x, z, world_width,
                                              world_back_y, coin_height)
                              : project(x, y, z, world_width, world_back_y,
                                        coin_height);
    const String color_text = body_colors.get(
        kind, body_colors.get("default", "#c9c5b8"));
    const Color color = Color::from_string(color_text, default_color);
    const int64_t frame = ((id.hash() % 4) + 4) % 4;
    const double rotation = ROTATIONS[frame];
    const double depth_scale =
        lerpd(1.0, REAR_WIDTH_FACTOR, clampd(y / world_back_y, 0.0, 1.0));
    const double visual_scale =
        depth_scale * double(body.get("radius", int64_t(coin_radius))) /
        coin_radius;
    const double c = std::cos(rotation) * visual_scale;
    const double s = std::sin(rotation) * visual_scale;
    const int64_t offset = instance * 12;
    buffer[offset] = c;
    buffer[offset + 1] = -s;
    buffer[offset + 2] = 0.0f;
    buffer[offset + 3] = point.x;
    buffer[offset + 4] = s;
    buffer[offset + 5] = c;
    buffer[offset + 6] = 0.0f;
    buffer[offset + 7] = point.y;
    buffer[offset + 8] = color.r;
    buffer[offset + 9] = color.g;
    buffer[offset + 10] = color.b;
    buffer[offset + 11] = color.a;
    if (falling) {
      const Vector2 shadow_point =
          on_board && z > board_bottom + coin_height
              ? project_board(board, x, z, world_width, world_back_y,
                              coin_height)
              : project(x, y, board_bottom, world_width, world_back_y,
                        coin_height);
      Dictionary shadow;
      shadow["point"] = shadow_point;
      shadow["scale"] = visual_scale;
      shadows.append(shadow);
    }
    if (kind != "coin") {
      Dictionary feature;
      feature["kind"] = kind;
      feature["point"] = point;
      features.append(feature);
    }
  }
  Dictionary result;
  result["count"] = count;
  result["buffer"] = buffer;
  result["shadows"] = shadows;
  result["features"] = features;
  return result;
}

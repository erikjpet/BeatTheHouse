#include "coin_pusher_native_core.h"

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <limits>
#include <memory>
#include <unordered_map>
#include <vector>

using namespace godot;

namespace {
constexpr int64_t FP = 1000, FIXED_HZ = 60, HARD_CEILING = 600, PASSES = 6;
constexpr int64_t GRAVITY = 1800, AIR_NUM = 61, AIR_DEN = 64, SLEEP_SPEED = 140,
                  SLEEP_TICKS = 5, HARD_IMPACT_SPEED = 12000,
                  LANDING_SCATTER_SPEED = 3200, TERMINAL_FALL_FLOOR_Z = -5100;
constexpr int64_t SLOP = 60, BETA = 600, REST_BODY = 100, REST_PEG = 520,
                  MU_BODY = 500, MU_DECK = 700, MU_PLATFORM = 800;
constexpr int64_t PEG_CONTACT_HYSTERESIS = 320, PEG_IMPACT_EVENT_SPEED = 3600,
                  PEG_CROWN_ESCAPE_ACCEL = 450;
constexpr int64_t SUPPORT_TOL = 400, SUPPORT_MARGIN = 800;
constexpr std::array<int, 240> COS = {
    1000,  1000,  999,  997,  995,  991,  988,  983,  978,  972,  966,  959,
    951,   943,   934,  924,  914,  903,  891,  879,  866,  853,  839,  824,
    809,   793,   777,  760,  743,  725,  707,  688,  669,  649,  629,  609,
    588,   566,   545,  522,  500,  477,  454,  431,  407,  383,  358,  334,
    309,   284,   259,  233,  208,  182,  156,  131,  105,  78,   52,   26,
    0,     -26,   -52,  -78,  -105, -131, -156, -182, -208, -233, -259, -284,
    -309,  -334,  -358, -383, -407, -431, -454, -477, -500, -522, -545, -566,
    -588,  -609,  -629, -649, -669, -688, -707, -725, -743, -760, -777, -793,
    -809,  -824,  -839, -853, -866, -879, -891, -903, -914, -924, -934, -943,
    -951,  -959,  -966, -972, -978, -983, -988, -991, -995, -997, -999, -1000,
    -1000, -1000, -999, -997, -995, -991, -988, -983, -978, -972, -966, -959,
    -951,  -943,  -934, -924, -914, -903, -891, -879, -866, -853, -839, -824,
    -809,  -793,  -777, -760, -743, -725, -707, -688, -669, -649, -629, -609,
    -588,  -566,  -545, -522, -500, -477, -454, -431, -407, -383, -358, -334,
    -309,  -284,  -259, -233, -208, -182, -156, -131, -105, -78,  -52,  -26,
    0,     26,    52,   78,   105,  131,  156,  182,  208,  233,  259,  284,
    309,   334,   358,  383,  407,  431,  454,  477,  500,  522,  545,  566,
    588,   609,   629,  649,  669,  688,  707,  725,  743,  760,  777,  793,
    809,   824,   839,  853,  866,  879,  891,  903,  914,  924,  934,  943,
    951,   959,   966,  972,  978,  983,  988,  991,  995,  997,  999,  1000};

inline int64_t divi(int64_t a, int64_t b) { return b == 0 ? 0 : a / b; }
inline int64_t clampi(int64_t v, int64_t lo, int64_t hi) {
  return std::max(lo, std::min(hi, v));
}
inline int64_t posmod(int64_t v, int64_t m) {
  int64_t r = v % m;
  return r < 0 ? r + m : r;
}
inline int64_t isqrt(int64_t v) {
  if (v <= 0)
    return 0;
  int64_t estimate = v, next = divi(estimate + divi(v, estimate), 2);
  while (next < estimate) {
    estimate = next;
    next = divi(estimate + divi(v, estimate), 2);
  }
  return estimate;
}
inline int64_t floor_div(int64_t v, int64_t d) {
  if (d <= 0)
    return 0;
  return v >= 0 ? v / d : -divi(-v + d - 1, d);
}

struct Geo {
  int64_t width = 100000, lip = 4000, payout_run = 6500,
          payout_rise = 900, deck = 0, top = 3600, extended = 43000,
          retracted = 61000, plate = 78000, plate_gap = 400, drop_y = 73000,
          drop_z = 24000, gutter = 3000, period = 240, ramp = 24, coin_r = 2350,
          coin_h = 950, coin_m = 1000, coin_value = 1, jitter = 300,
          velocity_jitter = 0,
          join_impulse = 0,
          ceiling = 600;
  Array pegs, targets;
};
Geo geometry(const Dictionary &s) {
  Geo g;
  Dictionary d = s.get("machine_definition", Dictionary());
  Dictionary x = d.get("geometry", Dictionary());
  Dictionary st = d.get("stroke", Dictionary());
  Dictionary c = d.get("coins", Dictionary());
  Dictionary a = d.get("apparatus", Dictionary());
  g.width = x.get("width", g.width);
  g.lip = x.get("tray_lip_y", g.lip);
  g.payout_run = std::max<int64_t>(1, x.get("payout_ramp_run", g.payout_run));
  g.payout_rise = std::max<int64_t>(0, x.get("payout_ramp_rise", g.payout_rise));
  g.deck = x.get("deck_z", g.deck);
  g.top = x.get("platform_top_z", g.top);
  g.extended = x.get("face_extended_y", g.extended);
  g.retracted = x.get("face_retracted_y", g.retracted);
  g.plate = x.get("back_plate_y", g.plate);
  g.plate_gap = x.get("back_plate_gap", g.plate_gap);
  Dictionary board = a.get("drop_board", Dictionary());
  g.drop_y = board.get("y", x.get("drop_y", g.drop_y));
  g.drop_z = board.get("z_top", x.get("drop_z", g.drop_z));
  g.gutter = x.get("gutter_x", g.gutter);
  g.period = std::max<int64_t>(1, st.get("period_ticks", g.period));
  g.ramp = std::max<int64_t>(1, st.get("ramp_ticks", g.ramp));
  g.coin_r = c.get("radius", g.coin_r);
  g.coin_h = c.get("height", g.coin_h);
  g.coin_m = std::max<int64_t>(1, c.get("mass", g.coin_m));
  g.coin_value = c.get("value", g.coin_value);
  g.jitter = std::max<int64_t>(0, a.get("release_jitter", g.jitter));
  g.velocity_jitter = std::max<int64_t>(0, a.get("release_velocity_jitter", 0));
  g.join_impulse = std::max<int64_t>(0, a.get("upper_row_join_impulse", 0));
  g.ceiling = clampi(d.get("ceiling", g.ceiling), 1, HARD_CEILING);
  g.pegs = a.get("pegs", Array());
  g.targets = a.get("targets", Array());
  return g;
}
int64_t face_y(const Geo &g, int64_t phase) {
  int64_t i = posmod(phase, g.period);
  int64_t cosine = COS[(size_t)(i * (int64_t)COS.size() / g.period)];
  return g.extended + divi((g.retracted - g.extended) * (FP - cosine), 2 * FP);
}

struct Body {
  Dictionary ref, meta;
  std::vector<String> support_ids;
  String id, kind, rest, support, peg_key, exit_state;
  int64_t x = 0, y = 0, z = 0, vx = 0, vy = 0, vz = 0, xr = 0, yr = 0, zr = 0,
          r = 2350, h = 950, m = 1000, sleep_ticks = 0, fall_start_z = 0,
          exit_start_tick = -1, support_anchor_x = 0, support_anchor_y = 0,
          id_number = 0, id_hash = 0;
  bool sleeping = false, carried = false, plate_blocked = false,
       pending_deposit = false, has_fall_start = false, peg_contact = false,
       has_support_anchor = false, id_numbered = false, falling = false,
       terminal_state = false;
};
struct PresentationMotionBody {
  String id, support;
  int64_t y = 0;
};
PackedInt64Array pack_presentation_bodies(const std::vector<Body> &source) {
  PackedInt64Array packed;
  packed.resize(source.size() * 9);
  for (int64_t i = 0; i < int64_t(source.size()); ++i) {
    const Body &q = source[size_t(i)];
    const int64_t offset = i * 9;
    packed[offset] = q.id_number;
    packed[offset + 1] = q.id_hash;
    packed[offset + 2] = q.x;
    packed[offset + 3] = q.y;
    packed[offset + 4] = q.z;
    packed[offset + 5] = q.r;
    packed[offset + 6] = q.falling ? 1 : 0;
    packed[offset + 7] = q.kind == "coin" ? 0 : q.kind == "rider" ? 1 : q.kind == "puck" ? 2 : q.kind == "fragment" ? 3 : 4;
    packed[offset + 8] = q.support == "platform" ? 1 : q.support == "deck" ? 2 : q.support == "body" ? 3 : q.support.is_empty() ? 0 : 4;
  }
  return packed;
}
bool z_overlap(const Body &l, const Body &r) {
  return l.z < r.z + r.h && r.z < l.z + l.h;
}
bool body_id_less(const Body &left, const Body &right) {
  if (left.id_numbered && right.id_numbered &&
      left.id_number != right.id_number)
    return left.id_number < right.id_number;
  return left.id < right.id;
}
bool body_id_equal(const Body &left, const Body &right) {
  if (left.id_numbered && right.id_numbered)
    return left.id_number == right.id_number;
  return left.id == right.id;
}
void wake(Body &b) {
  if (b.sleeping)
    b.sleep_ticks = 0;
  b.sleeping = false;
  if (!b.falling)
    b.rest = "settling";
}
bool terminal(const Body &b) { return b.terminal_state; }
void update_sleep(Body &b) {
  int64_t speed = std::abs(b.vx) + std::abs(b.vy) + std::abs(b.vz);
  if (speed < SLEEP_SPEED) {
    b.vx = b.vy = b.vz = 0;
    if (++b.sleep_ticks >= SLEEP_TICKS) {
      b.sleeping = true;
      b.xr = b.yr = b.zr = 0;
    }
  } else {
    b.sleep_ticks = 0;
    b.sleeping = false;
  }
}
void friction(Body &b, int64_t mu) {
  int64_t keep = clampi(FP - divi(mu, 8), 0, FP);
  b.vx = divi(b.vx * keep, FP);
  b.vy = divi(b.vy * keep, FP);
}
void advance(int64_t &position, int64_t &remainder, int64_t velocity) {
  int64_t total = remainder + velocity, whole = divi(total, FIXED_HZ);
  position += whole;
  remainder = total - whole * FIXED_HZ;
}

struct Grid {
  static constexpr int CAP = 2048;
  std::array<int64_t, CAP> kx{}, ky{};
  std::array<int, CAP> head{};
  std::array<uint32_t, CAP> generation{};
  uint32_t current_generation = 0;
  std::vector<int> next;
  int slot(int64_t x, int64_t y, bool insert) {
    int s = (int)(((x * 73856093) ^ (y * 19349663)) & (CAP - 1));
    for (int p = 0; p < CAP; ++p) {
      if (generation[s] != current_generation) {
        if (!insert)
          return -1;
        generation[s] = current_generation;
        kx[s] = x;
        ky[s] = y;
        head[s] = 0;
        return s;
      }
      if (kx[s] == x && ky[s] == y)
        return s;
      s = (s + 1) & (CAP - 1);
    }
    return -1;
  }
  void rebuild(const std::vector<Body> &b) {
    if (++current_generation == 0) {
      generation.fill(0);
      current_generation = 1;
    }
    next.resize(b.size());
    for (int i = (int)b.size() - 1; i >= 0; --i) {
      int s = slot(floor_div(b[i].x, 10000), floor_div(b[i].y, 10000), true);
      next[i] = head[s];
      head[s] = i + 1;
    }
  }
  int first(int64_t x, int64_t y) {
    int s = slot(x, y, false);
    return s < 0 ? -1 : head[s] - 1;
  }
  int after(int i) const {
    return i < 0 || i >= (int)next.size() ? -1 : next[i] - 1;
  }
};

struct GodotStringHash {
  size_t operator()(const String &value) const noexcept {
    return static_cast<size_t>(value.hash());
  }
};

struct Kernel {
  Dictionary state, config;
  Geo g;
  std::vector<Body> b;
  std::vector<std::pair<int, int>> pair_scratch;
  std::vector<uint8_t> queued_scratch;
  std::vector<int> queue_scratch, static_scratch, support_indices_scratch;
  Grid grid_scratch;
  std::unordered_map<String, int, GodotStringHash> body_index_scratch;
  Array events;
  int64_t collisions = 0, candidate_peak = 0;
  bool energy_ok = true, conservation_ok = true;
  Kernel(Dictionary s, Dictionary c, bool own_call_config = false)
      : state(s),
        config(own_call_config ? c.duplicate(false) : c),
        g(geometry(s)) {}
  void resume(Dictionary s, Dictionary c) {
    state = s;
    config = c.duplicate(false);
  }
  void release_call_context() {
    // A cached kernel owns only the numeric solver state between calls. The
    // call config can contain RefCounted helpers such as RngStream; retaining
    // it in the process-lifetime live cache leaks that object at shutdown.
    // Kernel config is a shallow container copy, so clearing releases any
    // per-call RefCounted values without mutating caller-owned storage.
    config.clear();
    config = Dictionary();
  }
  bool load() {
    if (String(state.get("schema", "")) != "coin_pusher_machine_v3" ||
        int64_t(state.get("version", 0)) != 3)
      return false;
    Array a = state.get("bodies", Array());
    if (a.size() > g.ceiling)
      return false;
    b.reserve(a.size());
    for (int i = 0; i < a.size(); ++i) {
      Dictionary r = a[i];
      Body q;
      q.ref = r;
      q.id = r.get("id", "");
      q.id_numbered = q.id.length() == 10 && q.id.begins_with("body_") &&
                        q.id.substr(5).is_valid_int();
      q.id_number = q.id.trim_prefix("body_").to_int();
      q.id_hash = q.id.hash();
      q.kind = r.get("kind", "coin");
      q.x = r.get("x", 0);
      q.y = r.get("y", 0);
      q.z = r.get("z", 0);
      q.vx = r.get("vx", 0);
      q.vy = r.get("vy", 0);
      q.vz = r.get("vz", 0);
      q.xr = r.get("x_remainder", 0);
      q.yr = r.get("y_remainder", 0);
      q.zr = r.get("z_remainder", 0);
      q.r = r.get("radius", g.coin_r);
      q.h = r.get("height", g.coin_h);
      q.m = std::max<int64_t>(1, r.get("mass", FP));
      q.sleep_ticks = r.get("sleep_ticks", 0);
      q.sleeping = r.get("sleeping", false);
      q.rest = r.get("rest_state", "falling");
      q.falling = q.rest == "falling";
      q.support = r.get("support_kind", "");
      Array source_support_ids = r.get("support_ids", Array());
      q.support_ids.reserve(source_support_ids.size());
      for (int support_index = 0; support_index < source_support_ids.size(); ++support_index)
        q.support_ids.push_back(source_support_ids[support_index]);
      q.has_support_anchor = r.has("support_anchor_x") && r.has("support_anchor_y");
      q.support_anchor_x = r.get("support_anchor_x", 0);
      q.support_anchor_y = r.get("support_anchor_y", 0);
      q.exit_state = r.get("exit_state", "");
      q.terminal_state = !q.exit_state.is_empty();
      q.exit_start_tick = r.get("exit_start_tick", -1);
      q.carried = r.get("carried_sleep", false);
      q.plate_blocked = r.get("plate_blocked", false);
      q.peg_key = r.get("peg_contact_key", "");
      q.pending_deposit = r.get("pending_platform_deposit", false);
      q.has_fall_start = r.has("fall_start_z");
      q.fall_start_z = r.get("fall_start_z", q.z);
      q.meta = r.get("meta", Dictionary());
      b.push_back(q);
    }
    return true;
  }
  int64_t body_energy(const Body &q) const {
    // Compare the exact common fixed-point numerator. Per-axis/per-body
    // truncation can otherwise manufacture a one-unit accounting gain.
    return q.m * (q.vx * q.vx + q.vy * q.vy + q.vz * q.vz);
  }
  int64_t deck_surface_z(int64_t y) const {
    if (g.payout_rise <= 0 || y >= g.lip + g.payout_run)
      return g.deck;
    if (y <= g.lip)
      return g.deck + g.payout_rise;
    return g.deck + divi((g.lip + g.payout_run - y) * g.payout_rise,
                         g.payout_run);
  }
  int64_t apply_payout_ramp_gravity(Body &q) const {
    if (g.payout_rise <= 0 || q.y <= g.lip || q.y >= g.lip + g.payout_run ||
        std::abs(q.vy) <= SLEEP_SPEED)
      return 0;
    int64_t before = body_energy(q);
    int64_t slope_length =
        std::max<int64_t>(1, isqrt(g.payout_run * g.payout_run +
                                  g.payout_rise * g.payout_rise));
    q.vy += divi(GRAVITY * g.payout_rise, slope_length);
    return std::max<int64_t>(0, body_energy(q) - before);
  }
  int64_t energy() const {
    int64_t e = 0;
    for (const Body &q : b)
      if (!q.sleeping)
        e += body_energy(q);
    return e;
  }
  bool update_motor() {
    int64_t target = config.get("motor_enabled", true)
                         ? int64_t(state.get("motor_target_rate_fp", FP))
                         : 0;
    int64_t rate = state.get("motor_rate_fp", FP),
            delta = divi(FP + g.ramp - 1, g.ramp);
    rate = rate < target   ? std::min(target, rate + delta)
           : rate > target ? std::max(target, rate - delta)
                           : rate;
    state["motor_rate_fp"] = rate;
    state["previous_face_y"] = state.get("face_y", face_y(g, 0));
    int64_t previous_phase = state.get("phase_fp", 0);
    state["phase_fp"] = posmod(previous_phase + rate, g.period * FP);
    bool completed = rate > 0 && int64_t(state.get("phase_fp", 0)) < previous_phase;
    if (completed)
      state["stroke_cycle_serial"] = int64_t(state.get("stroke_cycle_serial", 0)) + 1;
    state["face_y"] = face_y(g, divi(state.get("phase_fp", 0), FP));
    return completed;
  }
  void carry(int64_t oldf, int64_t newf, int64_t delta) {
    int64_t bottom = g.top + g.plate_gap;
    for (Body &q : b) {
      if (terminal(q))
        continue;
      String previous = q.support;
      bool direct = previous == "platform" ||
                    (std::abs(q.z - g.top) <= SUPPORT_TOL && q.y >= oldf),
           inherited = q.carried && previous == "body",
           riding = direct || inherited;
      if (riding) {
        int64_t proposed =
            q.y + clampi(delta,
                         -std::max<int64_t>(1, divi(MU_PLATFORM * GRAVITY, FP)),
                         std::max<int64_t>(1, divi(MU_PLATFORM * GRAVITY, FP)));
        bool blocked = q.z + q.h > bottom && proposed + q.r > g.plate;
        if (blocked) {
          proposed = g.plate - q.r;
          q.plate_blocked = true;
          if (delta != 0)
            wake(q);
        } else
          q.plate_blocked = false;
        q.y = proposed;
        if (proposed >= newf)
          q.support = direct ? String("platform") : previous;
        else if (direct) {
          q.pending_deposit = true;
          q.support = "";
          wake(q);
        }
        if (q.sleeping && !blocked)
          q.carried = true;
      }
    }
  }
  void face_push(int64_t oldf, int64_t newf, int64_t delta) {
    if (delta >= 0)
      return;
    for (Body &q : b) {
      if (terminal(q))
        continue;
      if (q.z >= g.top)
        continue;
      if (q.y < newf && newf - (q.y + q.r) <= q.r)
        wake(q);
      if (q.y + q.r >= newf && q.y - q.r <= oldf) {
        q.y = newf - q.r;
        q.vy = std::min(q.vy, delta * FIXED_HZ);
        wake(q);
      }
    }
  }
  void integrate() {
    for (Body &q : b) {
      if (q.sleeping)
        continue;
      q.vz -= GRAVITY;
      q.vx = divi(q.vx * AIR_NUM, AIR_DEN);
      q.vy = divi(q.vy * AIR_NUM, AIR_DEN);
      advance(q.x, q.xr, q.vx);
      advance(q.y, q.yr, q.vy);
      advance(q.z, q.zr, q.vz);
    }
  }
  int64_t pegs() {
    int64_t peg_work = 0;
    for (Body &q : b)
      q.peg_contact = false;
    for (Body &q : b) {
      if (q.sleeping || std::abs(q.y - g.drop_y) > q.r)
        continue;
      if (!q.falling) {
        q.peg_key = "";
        continue;
      }
      String previous_peg_key = q.peg_key, current_peg_key;
      for (int i = 0; i < g.pegs.size(); ++i) {
        Dictionary p = g.pegs[i];
        int64_t pre_x = q.x, pre_z = q.z;
        int64_t dx = q.x - int64_t(p.get("x", 0)),
                dz = q.z - int64_t(p.get("z", 0)),
                minimum = q.r + int64_t(p.get("r", 1200)),
                ds = dx * dx + dz * dz;
        if (ds >= minimum * minimum)
          continue;
        current_peg_key = String::num_int64(i);
        int64_t d = std::max<int64_t>(1, isqrt(ds)), nx = divi(dx * FP, d),
                nz = divi(dz * FP, d), pen = minimum - d,
                corr = divi(std::max<int64_t>(0, pen - SLOP) * BETA, FP);
        // A vertical crown already has the valid radial normal (0,+1). Never
        // steer it from peg identity; only coincident centers are undefined.
        if (ds == 0) {
          nx = FP;
          nz = 0;
        }
        if (ds == 0) {
          q.x += divi(nx * corr, FP);
          q.z += divi(nz * corr, FP);
        } else {
          // Use exact radial components for positional separation. Rounding
          // the normal first maps a one-unit offset to a false vertical pin.
          auto radial_correction = [&](int64_t component) {
            if (component == 0 || corr <= 0)
              return int64_t(0);
            int64_t magnitude = divi(std::abs(component) * corr + d - 1, d);
            return component > 0 ? magnitude : -magnitude;
          };
          q.x += radial_correction(dx);
          q.z += radial_correction(dz);
        }
        int64_t rel = divi(q.vx * nx + q.vz * nz, FP);
        if (rel < 0) {
          // Resting-contact stabilization prevents gravity and discrete
          // correction from sustaining a perpetual micro-bounce on a peg.
          // Insertion is provenance, not a permanent chatter exemption.
          int64_t restitution = -rel < GRAVITY * 2 ? 0 : REST_PEG;
          int64_t impulse = -divi((FP + restitution) * rel, FP);
          int64_t x_num = impulse * nx, z_num = impulse * nz;
          int64_t x_candidates[2] = {floor_div(x_num, FP), -floor_div(-x_num, FP)};
          int64_t z_candidates[2] = {floor_div(z_num, FP), -floor_div(-z_num, FP)};
          int64_t before_contact_energy = q.vx * q.vx + q.vz * q.vz;
          int64_t best_dx = 0, best_dz = 0, best_error = std::numeric_limits<int64_t>::max();
          bool found_conservative = false;
          for (int xi = 0; xi < 2; ++xi) {
            for (int zi = 0; zi < 2; ++zi) {
              int64_t dx_candidate = x_candidates[xi], dz_candidate = z_candidates[zi];
              int64_t after_contact_energy = (q.vx + dx_candidate) * (q.vx + dx_candidate) +
                                             (q.vz + dz_candidate) * (q.vz + dz_candidate);
              if (after_contact_energy > before_contact_energy)
                continue;
              int64_t error_x = dx_candidate * FP - x_num;
              int64_t error_z = dz_candidate * FP - z_num;
              int64_t error = error_x * error_x + error_z * error_z;
              if (!found_conservative || error < best_error ||
                  (error == best_error && (dx_candidate < best_dx ||
                   (dx_candidate == best_dx && dz_candidate < best_dz)))) {
                found_conservative = true;
                best_error = error;
                best_dx = dx_candidate;
                best_dz = dz_candidate;
              }
            }
          }
          q.vx += best_dx;
          q.vz += best_dz;
          int64_t friction_budget = divi(MU_BODY * impulse, FP);
          int64_t tx = -nz, tz = nx;
          int64_t tangent = divi(q.vx * tx + q.vz * tz, FP);
          // Disk-on-pin rotational compliance contributes twice the inverse
          // effective mass of translation. Without angular state, preserve
          // that 1:2 split rather than cancelling the complete COM tangent.
          int64_t tangent_impulse = previous_peg_key != current_peg_key ? clampi(-divi(tangent, 3), -friction_budget, friction_budget) : 0;
          int64_t friction_vx = q.vx, friction_vz = q.vz;
          int64_t tangent_dx = divi(tangent_impulse * tx, FP);
          int64_t tangent_dz = divi(tangent_impulse * tz, FP);
          // Approximate integer tangents can round a dissipative impulse into
          // a one-unit gain. Refuse that rounded candidate; conservation is a
          // solver invariant, not an assertion tolerance.
          if ((friction_vx + tangent_dx) * (friction_vx + tangent_dx) +
                  (friction_vz + tangent_dz) * (friction_vz + tangent_dz) >
              friction_vx * friction_vx + friction_vz * friction_vz) {
            tangent_impulse = 0;
            tangent_dx = 0;
            tangent_dz = 0;
          }
          q.vx = friction_vx + tangent_dx;
          q.vz = friction_vz + tangent_dz;
          int64_t remaining = std::max<int64_t>(0, friction_budget - std::abs(tangent_impulse));
          q.vy += clampi(-q.vy, -remaining, remaining);
        }
        // A disk exactly balanced on a round peg is unstable in reality, but
        // this 2-D model has no angular state to start the roll. Convert the
        // smallest physical offset or integration remainder into a gentle
        // gravity-driven crown acceleration so a coin bounces and rolls off
        // instead of remaining pinned indefinitely.
        if (std::abs(dx) <= std::max<int64_t>(1, divi(minimum, 12)) && std::abs(q.vx) < GRAVITY) {
          int64_t before_crown_energy = body_energy(q);
          int64_t crown_sign = dx < 0 ? -1 : (dx > 0 ? 1 : 0);
          if (crown_sign == 0)
            crown_sign = q.vx < 0 ? -1 : (q.vx > 0 ? 1 : 0);
          if (crown_sign == 0)
            crown_sign = q.xr < 0 ? -1 : (q.xr > 0 ? 1 : 0);
          if (crown_sign == 0)
            crown_sign = 1;
          q.vx += crown_sign * PEG_CROWN_ESCAPE_ACCEL;
          peg_work += std::max<int64_t>(0, body_energy(q) - before_crown_energy);
        }
        int64_t incoming_speed = std::max<int64_t>(0, -rel);
        if (previous_peg_key != current_peg_key && incoming_speed >= PEG_IMPACT_EVENT_SPEED) {
          Dictionary e;
          e["kind"] = "peg_impact";
          e["body_id"] = q.id;
          e["impact_speed"] = incoming_speed;
          e["peg_index"] = i;
          Dictionary peg;
          // Event schema is public parity data. JSON-authored geometry may enter
          // Godot as numeric Variants, so pin it to the integer solver contract.
          peg["x"] = int64_t(p.get("x", 0));
          peg["z"] = int64_t(p.get("z", 0));
          peg["r"] = int64_t(p.get("r", 1200));
          e["peg"] = peg;
          e["pre_x"] = pre_x;
          e["pre_z"] = pre_z;
          e["post_x"] = q.x;
          e["post_z"] = q.z;
          events.append(e);
        }
      }
      if (current_peg_key.is_empty() && !previous_peg_key.is_empty() && previous_peg_key.is_valid_int()) {
        int previous_index = int(previous_peg_key.to_int());
        if (previous_index >= 0 && previous_index < g.pegs.size()) {
          Dictionary previous_peg = g.pegs[previous_index];
          int64_t hold_dx = q.x - int64_t(previous_peg.get("x", 0));
          int64_t hold_dz = q.z - int64_t(previous_peg.get("z", 0));
          int64_t hold_radius = q.r + int64_t(previous_peg.get("r", 1200)) + PEG_CONTACT_HYSTERESIS;
          if (hold_dx * hold_dx + hold_dz * hold_dz < hold_radius * hold_radius)
            current_peg_key = previous_peg_key;
        }
      }
      q.peg_key = current_peg_key;
    }
    return peg_work;
  }
  const std::vector<std::pair<int, int>> &pairs(Grid &grid) {
    auto &p = pair_scratch;
    p.clear();
    p.reserve(std::min<size_t>(b.size() * 8, HARD_CEILING * 32));
    auto &queued = queued_scratch;
    queued.assign(b.size(), 0);
    auto &queue = queue_scratch;
    queue.clear();
    queue.reserve(b.size());
    for (int i = 0; i < (int)b.size(); ++i)
      if (!b[i].sleeping && !terminal(b[i])) {
        queued[i] = 1;
        queue.push_back(i);
      }
    for (size_t cursor = 0; cursor < queue.size(); ++cursor) {
      int i = queue[cursor];
      if (terminal(b[i]))
        continue;
      int64_t cx = floor_div(b[i].x, 10000), cy = floor_div(b[i].y, 10000);
      for (int oy = -1; oy <= 1; ++oy)
        for (int ox = -1; ox <= 1; ++ox)
          for (int j = grid.first(cx + ox, cy + oy); j >= 0;
               j = grid.after(j)) {
            if (i == j || terminal(b[j]) || !z_overlap(b[i], b[j]))
              continue;
            int64_t dx = b[j].x - b[i].x, dy = b[j].y - b[i].y,
                    mn = b[i].r + b[j].r;
            if (dx * dx + dy * dy >= mn * mn)
              continue;
            int lo = body_id_less(b[j], b[i]) ? j : i,
                hi = lo == i ? j : i;
            // Each body occupies exactly one grid cell and every neighbor cell
            // is visited once. The only duplicate is the reverse i/j traversal,
            // so canonical index order replaces the per-pass 65k-entry hash.
            if (i < j && p.size() < HARD_CEILING * 32)
              p.emplace_back(lo, hi);
            if (!queued[j]) {
              queued[j] = 1;
              queue.push_back(j);
            }
          }
    }
    std::sort(p.begin(), p.end(), [&](auto l, auto r) {
      return body_id_less(b[l.first], b[r.first]) ||
             (body_id_equal(b[l.first], b[r.first]) &&
              body_id_less(b[l.second], b[r.second]));
    });
    return p;
  }
  bool contact(Body &l, Body &r) {
    if (terminal(l) || terminal(r) || !z_overlap(l, r))
      return false;
    int64_t dx = r.x - l.x, dy = r.y - l.y;
    if (dx == 0 && dy == 0)
      dx = body_id_less(l, r) ? 1 : -1;
    int64_t mn = l.r + r.r, ds = dx * dx + dy * dy;
    if (ds >= mn * mn)
      return false;
    bool lawake = !l.sleeping, rawake = !r.sleeping;
    bool lmoving = std::abs(l.vx) + std::abs(l.vy) + std::abs(l.vz) >= SLEEP_SPEED;
    bool rmoving = std::abs(r.vx) + std::abs(r.vy) + std::abs(r.vz) >= SLEEP_SPEED;
    bool lincoming = l.falling;
    bool rincoming = r.falling;
    bool unilateral_l = lincoming && !rincoming, unilateral_r = rincoming && !lincoming;
    // A merely not-yet-asleep resting body must not perpetually wake an
    // overlapping sleeper. Only meaningful motion propagates an awake island.
    if (lawake && lmoving && !rawake && !unilateral_l)
      wake(r);
    else if (rawake && rmoving && !lawake && !unilateral_r)
      wake(l);
    int64_t d = std::max<int64_t>(1, isqrt(ds)), nx = divi(dx * FP, d),
            ny = divi(dy * FP, d),
            corr = divi(std::max<int64_t>(0, mn - d - SLOP) * BETA, FP),
            il = unilateral_r ? 0 : divi(FP * FP, l.m),
            ir = unilateral_l ? 0 : divi(FP * FP, r.m),
            sum = std::max<int64_t>(1, il + ir), lc = divi(corr * il, sum),
            rc = corr - lc;
    l.x -= divi(nx * lc, FP);
    l.y -= divi(ny * lc, FP);
    r.x += divi(nx * rc, FP);
    r.y += divi(ny * rc, FP);
    int64_t rvx = r.vx - l.vx, rvy = r.vy - l.vy,
            rn = divi(rvx * nx + rvy * ny, FP);
    bool changed = rn < -SLEEP_SPEED;
    if (rn < 0) {
      int64_t lvx_before = l.vx, lvy_before = l.vy, lvz_before = l.vz;
      int64_t rvx_before = r.vx, rvy_before = r.vy, rvz_before = r.vz;
      int64_t pair_energy_before = body_energy(l) + body_energy(r);
      int64_t imp = -divi((FP + REST_BODY) * rn, sum), ld = divi(imp * il, FP),
              rd = divi(imp * ir, FP);
      l.vx -= divi(ld * nx, FP);
      l.vy -= divi(ld * ny, FP);
      r.vx += divi(rd * nx, FP);
      r.vy += divi(rd * ny, FP);
      int64_t tx = -ny, ty = nx, rt = divi(rvx * tx + rvy * ty, FP),
              ti = clampi(-divi(rt * FP, sum), -divi(MU_BODY * imp, FP),
                          divi(MU_BODY * imp, FP)),
              ltd = divi(ti * il, FP), rtd = divi(ti * ir, FP);
      l.vx -= divi(ltd * tx, FP);
      l.vy -= divi(ltd * ty, FP);
      r.vx += divi(rtd * tx, FP);
      r.vy += divi(rtd * ty, FP);
      // Refuse an integer-rounded collision candidate if it violates the
      // dissipative contact law. Positional separation is still retained.
      if (body_energy(l) + body_energy(r) > pair_energy_before) {
        l.vx = lvx_before;
        l.vy = lvy_before;
        l.vz = lvz_before;
        r.vx = rvx_before;
        r.vy = rvy_before;
        r.vz = rvz_before;
        changed = false;
      }
    }
    if (changed) {
      if (!unilateral_r)
        wake(l);
      if (!unilateral_l)
        wake(r);
    }
    return true;
  }
  const std::vector<int> &static_candidates(const std::vector<uint8_t> &active,
                                            int64_t f) {
    auto &out = static_scratch;
    out.clear();
    out.reserve(b.size());
    int64_t bottom = g.top + g.plate_gap;
    for (int i = 0; i < (int)b.size(); ++i)
      if (active[i]) {
        Body &q = b[i];
        if (terminal(q))
          continue;
        if (q.x < q.r * 2 || q.x > g.width - q.r * 2 ||
            ((q.z + q.h) > bottom && (q.y + q.r * 2) > g.plate) ||
            (q.z < g.top && q.y < f && q.y + q.r * 2 > f))
          out.push_back(i);
      }
    return out;
  }
  int64_t static_contacts(const std::vector<int> &indices, int64_t f,
                          int64_t delta) {
    int64_t bottom = g.top + g.plate_gap, work = 0;
    for (int i : indices) {
      Body &q = b[i];
      if (terminal(q))
        continue;
      if (q.z < g.top && q.y < f && q.y > f - q.r) {
        int64_t before = body_energy(q), pen = q.y - (f - q.r),
                corr = divi(std::max<int64_t>(0, pen - SLOP) * BETA, FP),
                relative = delta * FIXED_HZ - q.vy;
        q.y -= corr;
        if (relative < 0)
          q.vy += relative;
        work += std::max<int64_t>(0, body_energy(q) - before);
      }
      if (q.z + q.h > bottom && q.y > g.plate - q.r) {
        int64_t pen = q.y - (g.plate - q.r),
                corr = divi(std::max<int64_t>(0, pen - SLOP) * BETA, FP);
        q.y -= corr;
        if (q.vy > 0)
          q.vy = 0;
      }
      if (q.y <= g.lip + q.r)
        continue;
      if (q.x < q.r) {
        int64_t pen = q.r - q.x,
                corr = divi(std::max<int64_t>(0, pen - SLOP) * BETA, FP);
        q.x += corr;
        if (q.vx < 0)
          q.vx = 0;
      } else if (q.x > g.width - q.r) {
        int64_t pen = q.x - (g.width - q.r),
                corr = divi(std::max<int64_t>(0, pen - SLOP) * BETA, FP);
        q.x -= corr;
        if (q.vx > 0)
          q.vx = 0;
      }
    }
    return work;
  }
  std::pair<int64_t, int64_t> landing_scatter(Body &q,
                                               int64_t impact_speed) {
    if (impact_speed < HARD_IMPACT_SPEED)
      return {0, 0};
    static constexpr int64_t directions[8][2] = {
        {1000, 0},   {707, 707},   {0, 1000},   {-707, 707},
        {-1000, 0}, {-707, -707}, {0, -1000},  {707, -707}};
    int64_t serial = std::max<int64_t>(0, q.meta.get("landing_contact_serial", 0));
    int64_t body_serial = q.id.trim_prefix("body_").to_int();
    int index = (int)posmod(body_serial + serial * 3, 8);
    int64_t speed = std::min<int64_t>(LANDING_SCATTER_SPEED,
                                      std::max<int64_t>(0, impact_speed / 8));
    int64_t sx = divi(directions[index][0] * speed, FP);
    int64_t sy = divi(directions[index][1] * speed, FP);
    q.vx += sx;
    q.vy += sy;
    q.meta["landing_contact_serial"] = serial + 1;
    return {sx, sy};
  }
  int64_t upper_row_join_pressure(int incoming_index) {
    if (g.join_impulse <= 0 || incoming_index < 0 || incoming_index >= (int)b.size())
      return 0;
    Body &incoming = b[incoming_index];
    int best = -1;
    int64_t best_distance_sq = 0;
    String best_id;
    for (int i = 0; i < (int)b.size(); ++i) {
      if (i == incoming_index)
        continue;
      Body &candidate = b[i];
      if (terminal(candidate) || candidate.kind != "coin" ||
          !(candidate.support == "platform" || candidate.carried) ||
          std::abs(candidate.z - incoming.z) > SUPPORT_TOL)
        continue;
      int64_t dx = candidate.x - incoming.x, dy = candidate.y - incoming.y;
      int64_t reach = candidate.r + incoming.r + SLOP;
      int64_t distance_sq = dx * dx + dy * dy;
      if (distance_sq > reach * reach)
        continue;
      if (best < 0 || distance_sq < best_distance_sq ||
          (distance_sq == best_distance_sq && candidate.id < best_id)) {
        best = i;
        best_distance_sq = distance_sq;
        best_id = candidate.id;
      }
    }
    if (best < 0)
      return 0;
    Body &neighbor = b[best];
    int64_t energy_before = body_energy(neighbor);
    neighbor.vy -= g.join_impulse;
    wake(neighbor);
    int64_t added_work = std::max<int64_t>(0, body_energy(neighbor) - energy_before);
    Dictionary e;
    e["kind"] = "upper_row_join_pressure";
    e["body_id"] = incoming.id;
    e["neighbor_body_id"] = best_id;
    e["impulse"] = g.join_impulse;
    e["added_work"] = added_work;
    events.append(e);
    return added_work;
  }
  int64_t resolve_supports(int64_t f, Grid &grid) {
    int64_t nestle_work = 0;
    // Support discovery runs twice per tick across the full machine. Keep the
    // hot candidate list in native storage and only materialize a Godot Array
    // for the final supported-body state. Constructing and sorting a Variant
    // array for every awake body dominated the Web side-module boundary even
    // though most candidates are discarded before publication.
    auto &support_indices = support_indices_scratch;
    if (support_indices.capacity() < 16)
      support_indices.reserve(16);
    for (int i = 0; i < (int)b.size(); ++i) {
      Body &q = b[i];
      if (q.sleeping || terminal(q))
        continue;
      support_indices.clear();
      String prev = q.pending_deposit ? String("platform") : q.support;
      bool previous_platform_root =
          prev == "platform" || (prev == "body" && q.carried);
      int64_t surface_z = q.y >= f ? g.top : deck_surface_z(q.y);
      String surface = q.y >= f ? String("platform") : String("deck");
      bool stable = q.z <= surface_z + SUPPORT_TOL;
      int64_t support_top = surface_z, count = 0, cx = 0, cy = 0,
              support_position_x = 0, support_position_y = 0;
      bool centered = false, xlo = false, xhi = false, ylo = false, yhi = false,
           top_carried = false;
      int64_t cellx = floor_div(q.x, 10000), celly = floor_div(q.y, 10000);
      for (int oy = -1; oy <= 1; ++oy)
        for (int ox = -1; ox <= 1; ++ox)
          for (int j = grid.first(cellx + ox, celly + oy); j >= 0;
               j = grid.after(j)) {
            if (i == j)
              continue;
            Body &s = b[j];
            if (terminal(s))
              continue;
            int64_t top = s.z + s.h;
            if (std::abs(q.z - top) > SUPPORT_TOL)
              continue;
            int64_t dx = s.x - q.x, dy = s.y - q.y,
                    reach = divi((q.r + s.r) * 9, 10);
            if (dx * dx + dy * dy >= reach * reach)
              continue;
            if (top < support_top)
              continue;
            if (top > support_top) {
              support_top = top;
              count = 0;
              centered = xlo = xhi = ylo = yhi = false;
              cx = cy = support_position_x = support_position_y = 0;
              top_carried = false;
              support_indices.clear();
            }
            ++count;
            support_indices.push_back(j);
            centered |= isqrt(dx * dx + dy * dy) < q.r / 2;
            xlo |= dx <= SUPPORT_MARGIN;
            xhi |= dx >= -SUPPORT_MARGIN;
            ylo |= dy <= SUPPORT_MARGIN;
            yhi |= dy >= -SUPPORT_MARGIN;
            cx += dx;
            cy += dy;
            support_position_x += s.x;
            support_position_y += s.y;
            bool carried = s.carried || s.support == "platform";
            top_carried |= carried;
          }
      if (count) {
        std::sort(support_indices.begin(), support_indices.end(), [&](int left, int right) {
          return body_id_less(b[left], b[right]);
        });
        stable |= centered || (xlo && xhi && ylo && yhi);
        if (!stable) {
          cx = divi(cx, count);
          cy = divi(cy, count);
          int64_t len = std::max<int64_t>(1, isqrt(cx * cx + cy * cy)),
                  before = body_energy(q);
          int64_t direction = count == 1 ? -1 : 1;
          q.vx += direction * divi(cx * GRAVITY, 6 * len);
          q.vy += direction * divi(cy * GRAVITY, 6 * len);
          nestle_work += std::max<int64_t>(0, body_energy(q) - before);
        }
      }
      if (stable && q.vz <= 0) {
        bool falling = q.falling;
        int64_t fall_start = q.has_fall_start ? q.fall_start_z : q.z;
        int64_t impact_speed = std::abs(q.vz);
        q.z = support_top;
        q.vz = 0;
        q.zr = 0;
        q.support = support_top == surface_z ? surface : "body";
        q.carried =
            q.support == "platform" || (q.support == "body" && top_carried);
        if (q.support == "body") {
          q.support_ids.clear();
          q.support_ids.reserve(support_indices.size());
          for (int support_index = 0; support_index < int(support_indices.size()); ++support_index)
            q.support_ids.push_back(b[support_indices[support_index]].id);
        } else {
          q.support_ids.clear();
        }
        q.has_support_anchor = q.support == "body";
        if (q.has_support_anchor) {
          q.support_anchor_x = divi(support_position_x, count);
          q.support_anchor_y = divi(support_position_y, count);
        }
        q.rest = "resting";
        q.falling = false;
        if (falling) {
          Dictionary e;
          e["kind"] = "impact";
          e["body_id"] = q.id;
          e["support"] = q.support;
          e["support_root"] = q.support == "platform" || (q.support == "body" && top_carried) ? String("platform") : String("deck");
          bool first_support = bool(q.meta.get("inserted", false)) && !bool(q.meta.get("first_support_recorded", false));
          e["first_support"] = first_support;
          String landing_quality = first_support ? (q.support == "body" ? String("supported_bad") : String("bed_level_good")) : String();
          e["landing_quality"] = landing_quality;
          if (first_support)
            q.meta["landing_quality"] = landing_quality;
          e["fall_height"] = std::max<int64_t>(0, fall_start - support_top);
          e["impact_speed"] = impact_speed;
          e["impact_class"] = impact_speed >= HARD_IMPACT_SPEED ? String("hard") : String("soft");
          e["stack_depth"] = std::max<int64_t>(
              0, divi(support_top - surface_z, std::max<int64_t>(1, q.h)));
          auto scatter = landing_scatter(q, impact_speed);
          e["landing_scatter_x"] = scatter.first;
          e["landing_scatter_y"] = scatter.second;
          events.append(e);
          if (first_support)
            q.meta["first_support_recorded"] = true;
          if (first_support)
            nestle_work += upper_row_join_pressure(i);
          q.has_fall_start = false;
        }
        friction(q, q.carried ? MU_PLATFORM : MU_DECK);
        if (!q.carried)
          nestle_work += apply_payout_ramp_gravity(q);
      } else {
        if (!q.falling) {
          q.fall_start_z = q.z;
          q.has_fall_start = true;
        }
        if (previous_platform_root)
          q.pending_deposit = true;
        q.support = "";
        q.support_ids.clear();
        q.has_support_anchor = false;
        q.carried = false;
        q.rest = "falling";
        q.falling = true;
        q.sleep_ticks = 0;
        q.sleeping = false;
      }
      if (previous_platform_root && q.support == "deck") {
        Dictionary e;
        e["kind"] = "platform_deposit";
        e["body_id"] = q.id;
        events.append(e);
        q.pending_deposit = false;
      }
    }
    return nestle_work;
  }
  void plinko_targets() {
    if (g.targets.is_empty())
      return;
    for (int i = int(b.size()) - 1; i >= 0; --i) {
      Body &q = b[i];
      if (terminal(q) || q.kind != "coin" || !q.falling ||
          std::abs(q.y - g.drop_y) > q.r)
        continue;
      for (int target_index = 0; target_index < g.targets.size(); ++target_index) {
        Dictionary target = g.targets[target_index];
        String target_id = target.get("id", "");
        Dictionary last_capture = state.get("target_last_capture", Dictionary());
        int64_t cooldown = std::max<int64_t>(0, target.get("cooldown_ticks", 0));
        if (last_capture.has(target_id) && int64_t(state.get("tick", 0)) - int64_t(last_capture[target_id]) < cooldown)
          continue;
        int64_t mouth = std::max<int64_t>(1, target.get("mouth_radius", target.get("radius", 2200)));
        int64_t dx = q.x - int64_t(target.get("x", 0));
        int64_t dz = q.z - int64_t(target.get("z", 0));
        if (dx * dx + dz * dz > mouth * mouth)
          continue;
        int64_t value = std::max<int64_t>(0, q.meta.get("value", 1));
        state["cup_consumed_count"] = int64_t(state.get("cup_consumed_count", 0)) + 1;
        state["cup_consumed_value"] = int64_t(state.get("cup_consumed_value", 0)) + value;
        last_capture[target_id] = state.get("tick", 0);
        state["target_last_capture"] = last_capture;
        Dictionary e;
        e["kind"] = "plinko_cup";
        e["target_id"] = target_id;
        e["body_id"] = q.id;
        e["x"] = q.x;
        e["z"] = q.z;
        e["reward"] = target.get("reward", Dictionary());
        e["metadata"] = q.meta.duplicate(true);
        e["tick"] = state.get("tick", 0);
        events.append(e);
        b.erase(b.begin() + i);
        break;
      }
    }
  }
  void advect_supported() {
    bool has_supported_body = false;
    for (const Body &q : b) {
      if (!terminal(q) && q.support == "body" && !q.carried &&
          q.has_support_anchor && !q.support_ids.empty()) {
        has_supported_body = true;
        break;
      }
    }
    if (!has_supported_body)
      return;
    // Support IDs are durable snapshot data, but resolving every ID by
    // rescanning the full body list turns carried stacks into O(n^2) work.
    // Build one immutable lookup for this tick; body erasure has already
    // finished and advect_supported does not change vector membership.
    auto &body_index = body_index_scratch;
    body_index.clear();
    body_index.reserve(b.size());
    for (int index = 0; index < static_cast<int>(b.size()); ++index)
      body_index.emplace(b[index].id, index);
    for (Body &q : b) {
      if (terminal(q) || q.support != "body" || q.carried || !q.has_support_anchor || q.support_ids.empty())
        continue;
      int64_t cx = 0, cy = 0, count = 0;
      for (int id_index = 0; id_index < q.support_ids.size(); ++id_index) {
        String wanted = q.support_ids[id_index];
        auto found = body_index.find(wanted);
        if (found == body_index.end())
          continue;
        const Body &support = b[found->second];
        if (terminal(support))
          continue;
        cx += support.x;
        cy += support.y;
        ++count;
      }
      if (!count)
        continue;
      cx = divi(cx, count);
      cy = divi(cy, count);
      int64_t dx = cx - q.support_anchor_x, dy = cy - q.support_anchor_y;
      q.x += dx;
      q.y += dy;
      q.support_anchor_x = cx;
      q.support_anchor_y = cy;
      if (dx || dy)
        wake(q);
    }
  }
  void exits() {
    for (int i = (int)b.size() - 1; i >= 0; --i) {
      Body &q = b[i];
      if (terminal(q)) {
        if (q.z > TERMINAL_FALL_FLOOR_Z)
          continue;
        String landed_outcome = q.exit_state == "tray_fall" ? String("tray") : String("gutter");
        Dictionary entry;
        entry["body_id"] = q.id;
        entry["kind"] = q.kind;
        entry["value"] = q.meta.get("value", q.kind == "coin" ? 1 : 0);
        entry["item_id"] = q.meta.get("item_id", "");
        entry["provenance"] = q.meta.get("provenance", Dictionary());
        Array ledger = state.get(
            landed_outcome == "tray" ? "tray_ledger" : "gutter_ledger", Array());
        ledger.append(entry);
        state[landed_outcome == "tray" ? "tray_ledger" : "gutter_ledger"] = ledger;
        Dictionary ev;
        ev["kind"] = landed_outcome;
        ev["outcome"] = landed_outcome;
        ev["body_id"] = q.id;
        ev["body_kind"] = q.kind;
        ev["x"] = q.x;
        ev["radius"] = q.r;
        ev["height"] = q.h;
        ev["mass"] = q.m;
        ev["tick"] = state.get("tick", 0);
        ev["fall_ticks"] = std::max<int64_t>(
            1, int64_t(state.get("tick", 0)) - q.exit_start_tick);
        ev["stroke_cycle"] = state.get("stroke_cycle_serial", 0);
        ev["phase_fp"] = state.get("phase_fp", 0);
        ev["metadata"] = q.meta.duplicate(true);
        events.append(ev);
        b.erase(b.begin() + i);
        continue;
      }
      String outcome;
      if (q.y - q.r < g.lip)
        outcome = (q.x >= g.gutter && q.x <= g.width - g.gutter)
                      ? String("tray")
                      : String("gutter");
      else if (q.x + q.r < g.gutter || q.x - q.r > g.width - g.gutter)
        outcome = "gutter";
      if (outcome.is_empty())
        continue;
      q.exit_state = outcome + "_fall";
      q.terminal_state = true;
      q.exit_start_tick = state.get("tick", 0);
      q.rest = "terminal_fall";
      q.falling = false;
      q.support = "";
      q.support_ids.clear();
      q.carried = false;
      q.sleeping = false;
      q.sleep_ticks = 0;
      q.vz = std::min<int64_t>(0, q.vz);
      // Preserve shelf-crossing momentum; gravity supplies the visible drop.
      // Injecting forward speed here creates energy at the sensor boundary.
      q.vy = std::min<int64_t>(0, q.vy);
      q.pending_deposit = false;
      Dictionary ev;
      ev["kind"] = outcome + "_fall_start";
      ev["outcome"] = outcome;
      ev["body_id"] = q.id;
      ev["body_kind"] = q.kind;
      ev["x"] = q.x;
      ev["z"] = q.z;
      ev["tick"] = state.get("tick", 0);
      events.append(ev);
    }
  }
  void nudge(int64_t x, int64_t y) {
    for (Body &q : b) {
      if (terminal(q))
        continue;
      q.vx += divi(x * FP, q.m);
      q.vy += divi(y * FP, q.m);
      wake(q);
    }
  }
  void add_drop(Object *rng, int64_t x, int64_t density,
                const Dictionary &provenance = Dictionary(), bool bonus_origin = false) {
    if ((int64_t)b.size() >= g.ceiling) {
      state["refused_inserts"] = int64_t(state.get("refused_inserts", 0)) + 1;
      Dictionary e;
      e["kind"] = "insert_refused";
      e["reason"] = "ceiling";
      e["returned"] = true;
      events.append(e);
      return;
    }
    int64_t jitter = 0;
    if (rng && g.jitter > 0)
      jitter = int64_t(rng->call("randi_range", -g.jitter, g.jitter));
    Body q;
    int64_t next_id = state.get("next_body_id", 1);
    q.id = String("body_") + String::num_int64(next_id).pad_zeros(5);
    q.id_numbered = next_id >= 0 && next_id <= 99999;
    q.id_number = next_id;
    q.id_hash = q.id.hash();
    state["next_body_id"] = next_id + 1;
    q.kind = "coin";
    q.x = clampi(x + jitter, g.coin_r, g.width - g.coin_r);
    q.y = g.drop_y;
    q.z = g.drop_z;
    if (rng && g.velocity_jitter > 0)
      q.vx = int64_t(rng->call("randi_range", -g.velocity_jitter, g.velocity_jitter));
    q.fall_start_z = q.z;
    q.has_fall_start = true;
    q.r = g.coin_r;
    q.h = g.coin_h;
    q.m = g.coin_m * std::max<int64_t>(1, density);
    q.rest = "falling";
    q.falling = true;
    q.meta["value"] = g.coin_value;
    q.meta["provenance"] = provenance.duplicate(true);
    q.meta["inserted"] = true;
    b.push_back(q);
    int64_t wake_radius = q.r * 3, wake_sq = wake_radius * wake_radius;
    for (Body &near : b) {
      if (near.id == q.id)
        continue;
      int64_t dx = near.x - q.x, dy = near.y - q.y;
      if (dx * dx + dy * dy <= wake_sq)
        wake(near);
    }
    if (bonus_origin)
      state["external_origin_count"] = int64_t(state.get("external_origin_count", 0)) + 1;
    else
      state["accepted_inserts"] = int64_t(state.get("accepted_inserts", 0)) + 1;
    Dictionary e;
    e["kind"] = "insert";
    e["body_id"] = q.id;
    e["x"] = q.x;
    events.append(e);
  }
  void inputs(Array trace, int64_t &cursor) {
    while (cursor < trace.size()) {
      Dictionary in = trace[cursor];
      if (int64_t(in.get("tick", -1)) != int64_t(state.get("tick", 0)))
        break;
      String k = in.get("kind", "");
      if (k == "nudge")
        nudge(in.get("x", 0), in.get("y", 0));
      else if (k == "skill_stop") {
        bool e = in.get("engaged", false);
        state["motor_run_rate_fp"] = int64_t(in.get("resume_rate_fp", state.get("motor_run_rate_fp", FP)));
        state["skill_stop_engaged"] = e;
        state["motor_target_rate_fp"] = e ? 0 : int64_t(state.get("motor_run_rate_fp", FP));
      } else if (k == "motor_rate") {
        int64_t rate = std::max<int64_t>(0, in.get("rate_fp", FP));
        state["motor_run_rate_fp"] = rate;
        if (!bool(state.get("skill_stop_engaged", false)))
          state["motor_target_rate_fp"] = rate;
      } else if (k == "drop") {
        Variant rv = config.get("rng", Variant());
        Object *rng = rv.get_type() == Variant::OBJECT ? (Object *)rv : nullptr;
        add_drop(rng, in.get("x", state.get("carriage_x", g.width / 2)),
                 in.get("density", 1), in.get("provenance", Dictionary()),
                 in.get("bonus_origin", false));
      } else if (k == "carriage") {
        Dictionary def = state.get("machine_definition", Dictionary());
        Dictionary apparatus = def.get("apparatus", Dictionary());
        Dictionary rail = apparatus.get("rail", Dictionary());
        int64_t x = in.get("x", state.get("carriage_x", g.width / 2));
        state["carriage_x"] = clampi(x, rail.get("x_min", 0),
                                     rail.get("x_max", g.width));
      } else if (k == "hole") {
        Dictionary def = state.get("machine_definition", Dictionary());
        Dictionary apparatus = def.get("apparatus", Dictionary());
        Array holes = apparatus.get("holes", Array());
        if (!holes.is_empty()) {
          int64_t index = clampi(in.get("index", 0), 0, holes.size() - 1);
          state["selected_hole"] = index;
          state["carriage_x"] = holes[index];
        }
      } else if (k == "gutter_return") {
        Array ledger = state.get("gutter_ledger", Array());
        String body_id = in.get("body_id", "");
        int found = -1;
        for (int ledger_index = ledger.size() - 1; ledger_index >= 0; --ledger_index) {
          Dictionary entry = ledger[ledger_index];
          if (String(entry.get("body_id", "")) == body_id) {
            found = ledger_index;
            break;
          }
        }
        if (found >= 0) {
          Dictionary entry = ledger[found];
          ledger.remove_at(found);
          state["gutter_ledger"] = ledger;
          Body q;
          q.ref = Dictionary();
          q.id = body_id;
          q.id_numbered = q.id.length() == 10 && q.id.begins_with("body_") &&
                            q.id.substr(5).is_valid_int();
          q.id_number = q.id.trim_prefix("body_").to_int();
          q.id_hash = q.id.hash();
          q.kind = in.get("body_kind", entry.get("kind", "coin"));
          q.r = in.get("radius", g.coin_r);
          q.h = in.get("height", g.coin_h);
          q.m = std::max<int64_t>(1, in.get("mass", g.coin_m));
          bool left = String(in.get("side", "left")) == "left";
          q.x = left ? g.gutter + q.r + 100 : g.width - g.gutter - q.r - 100;
          q.y = g.lip + q.r + 1200;
          q.z = g.deck + q.h;
          q.vx = left ? 900 : -900;
          q.vy = 300;
          q.vz = 0;
          q.rest = "falling";
          q.falling = true;
          q.support = "";
          q.fall_start_z = q.z;
          q.has_fall_start = true;
          q.meta = in.get("metadata", Dictionary());
          q.meta["value"] = entry.get("value", q.meta.get("value", 1));
          q.meta["item_id"] = entry.get("item_id", q.meta.get("item_id", ""));
          q.meta["provenance"] = entry.get("provenance", Dictionary());
          b.push_back(q);
        }
      } else if (k == "collect") {
        Array tray = state.get("tray_ledger", Array());
        int64_t collected_value = int64_t(state.get("collected_value", 0));
        for (int tray_index = 0; tray_index < tray.size(); ++tray_index) {
          Dictionary entry = tray[tray_index];
          collected_value += int64_t(entry.get("value", 0));
        }
        state["collected_count"] = int64_t(state.get("collected_count", 0)) + tray.size();
        state["collected_value"] = collected_value;
        state["tray_ledger"] = Array();
      }
      ++cursor;
    }
  }
  void write() {
    Array a;
    for (Body &q : b) {
      Dictionary r = q.ref;
      r["id"] = q.id;
      r["kind"] = q.kind;
      r["x"] = q.x;
      r["y"] = q.y;
      r["z"] = q.z;
      r["vx"] = q.vx;
      r["vy"] = q.vy;
      r["vz"] = q.vz;
      r["x_remainder"] = q.xr;
      r["y_remainder"] = q.yr;
      r["z_remainder"] = q.zr;
      r["radius"] = q.r;
      r["height"] = q.h;
      r["mass"] = q.m;
      r["sleep_ticks"] = q.sleep_ticks;
      r["sleeping"] = q.sleeping;
      r["rest_state"] = q.rest;
      r["support_kind"] = q.support;
      Array support_ids;
      support_ids.resize(q.support_ids.size());
      for (int support_index = 0; support_index < int(q.support_ids.size()); ++support_index)
        support_ids[support_index] = q.support_ids[support_index];
      r["support_ids"] = support_ids;
      if (q.has_support_anchor) {
        r["support_anchor_x"] = q.support_anchor_x;
        r["support_anchor_y"] = q.support_anchor_y;
      } else {
        r.erase("support_anchor_x");
        r.erase("support_anchor_y");
      }
      r["carried_sleep"] = q.carried;
      r["plate_blocked"] = q.plate_blocked;
      if (!q.peg_key.is_empty())
        r["peg_contact_key"] = q.peg_key;
      else
        r.erase("peg_contact_key");
      r["meta"] = q.meta;
      if (q.pending_deposit)
        r["pending_platform_deposit"] = true;
      else
        r.erase("pending_platform_deposit");
      if (q.has_fall_start)
        r["fall_start_z"] = q.fall_start_z;
      else
        r.erase("fall_start_z");
      if (terminal(q)) {
        r["exit_state"] = q.exit_state;
        r["exit_start_tick"] = q.exit_start_tick;
      } else {
        r.erase("exit_state");
        r.erase("exit_start_tick");
      }
      a.append(r);
    }
    state["bodies"] = a;
  }
  Dictionary run(int64_t ticks, bool reload = true) {
    auto start = std::chrono::steady_clock::now();
    if (ticks < 0)
      return Dictionary();
    if (reload) {
      b.clear();
      if (!load())
        return Dictionary();
    }
    events = Array();
    collisions = 0;
    candidate_peak = 0;
    energy_ok = true;
    conservation_ok = true;
    Array trace = config.get("input_trace", Array());
    int64_t cursor = 0;
    Grid &grid = grid_scratch;
    std::vector<Body> presentation_previous;
    std::vector<PresentationMotionBody> presentation_previous_motion;
    PackedInt64Array presentation_previous_packed;
    int64_t presentation_previous_face_y = state.get("face_y", face_y(g, 0));
    const bool capture_previous_views = bool(config.get("capture_previous_views", false));
    const bool capture_previous_packed = bool(config.get("capture_previous_packed", false));
    const bool capture_previous = capture_previous_views || capture_previous_packed;
    for (int64_t t = 0; t < ticks; ++t) {
      if (capture_previous && t == ticks - 1) {
        presentation_previous_motion.clear();
        presentation_previous_motion.reserve(b.size());
        for (const Body &q : b)
          presentation_previous_motion.push_back({q.id, q.support, q.y});
        if (capture_previous_views)
          presentation_previous = b;
        if (capture_previous_packed)
          presentation_previous_packed = pack_presentation_bodies(b);
        presentation_previous_face_y = state.get("face_y", face_y(g, 0));
      }
      inputs(trace, cursor);
      int64_t before = energy(), oldf = state.get("face_y", face_y(g, 0));
      bool cycle_completed = update_motor();
      if (cycle_completed) {
        Dictionary e;
        e["kind"] = "stroke_cycle";
        e["stroke_cycle"] = state.get("stroke_cycle_serial", 0);
        e["phase_fp"] = state.get("phase_fp", 0);
        e["tick"] = state.get("tick", 0);
        events.append(e);
      }
      int64_t newf = state.get("face_y", oldf), delta = newf - oldf;
      carry(oldf, newf, delta);
      face_push(oldf, newf, delta);
      int64_t gravity_before = energy();
      int64_t platform_work = std::max<int64_t>(0, gravity_before - before);
      integrate();
      int64_t gravity_work = std::max<int64_t>(0, energy() - gravity_before);
      int64_t peg_work = pegs();
      plinko_targets();
      grid.rebuild(b);
      int64_t nestle_work = resolve_supports(newf, grid);
      for (int pass = 0; pass < PASSES; ++pass) {
        grid.rebuild(b);
        const auto &ps = pairs(grid);
        candidate_peak = std::max<int64_t>(candidate_peak, ps.size());
        // pairs() starts from every awake body and breadth-first expands through
        // every overlapping neighbor. Its retained queued mask is therefore
        // exactly the active mask previously rebuilt from the same pairs here.
        const auto &active = queued_scratch;
        const auto &statics = static_candidates(active, newf);
        for (auto p : ps)
          if (contact(b[p.first], b[p.second]))
            ++collisions;
        platform_work += static_contacts(statics, newf, delta);
      }
      advect_supported();
      grid.rebuild(b);
      nestle_work += resolve_supports(newf, grid);
      for (Body &q : b)
        if (!q.sleeping && q.rest == "resting" && !q.support.is_empty())
          update_sleep(q);
      exits();
      state["tick"] = int64_t(state.get("tick", 0)) + 1;
      energy_ok &=
          energy() <= before + platform_work + gravity_work + peg_work + nestle_work;
      int64_t tick_tray = Array(state.get("tray_ledger", Array())).size();
      int64_t tick_gutter = Array(state.get("gutter_ledger", Array())).size();
      int64_t tick_collected = int64_t(state.get("collected_count", 0));
      int64_t tick_cup_consumed = int64_t(state.get("cup_consumed_count", 0));
      int64_t tick_origin = int64_t(state.get("opening_body_count", 0)) +
                            int64_t(state.get("accepted_inserts", 0)) +
                            int64_t(state.get("external_origin_count", 0));
      conservation_ok &=
          int64_t(b.size()) + tick_tray + tick_gutter + tick_collected + tick_cup_consumed == tick_origin;
    }
    if (bool(config.get("write_body_state", true)))
      write();
    int64_t active = b.size(),
            tray = Array(state.get("tray_ledger", Array())).size(),
            gutter = Array(state.get("gutter_ledger", Array())).size(),
            collected = int64_t(state.get("collected_count", 0)),
            cup_consumed = int64_t(state.get("cup_consumed_count", 0)),
            origin = int64_t(state.get("opening_body_count", 0)) +
                     int64_t(state.get("accepted_inserts", 0)) +
                     int64_t(state.get("external_origin_count", 0));
    Dictionary inv;
    inv["energy_ok"] = energy_ok;
    inv["conservation_ok"] = conservation_ok;
    inv["active"] = active;
    inv["tray"] = tray;
    inv["gutter"] = gutter;
    inv["collected"] = collected;
    inv["cup_consumed"] = cup_consumed;
    inv["origin"] = origin;
    inv["refused"] = state.get("refused_inserts", 0);
    state["last_invariants"] = inv;
    int64_t awake = 0;
    bool steady_without_motor = true, steady_with_motor = true;
    for (const Body &q : b) {
      awake += !q.sleeping;
      if (!q.sleeping) {
        steady_without_motor = false;
        steady_with_motor = false;
      } else if (q.support == "platform" && !q.carried) {
        steady_with_motor = false;
      }
    }
    int64_t usec = std::chrono::duration_cast<std::chrono::microseconds>(
                       std::chrono::steady_clock::now() - start)
                       .count();
    Dictionary m;
    m["fixed_ticks"] = ticks;
    m["body_count"] = active;
    m["awake_count"] = awake;
    m["collision_count"] = collisions;
    m["collision_passes"] = PASSES;
    m["candidate_count_peak"] = candidate_peak;
    m["candidate_pool_capacity"] = HARD_CEILING * 32;
    m["elapsed_usec"] = usec;
    m["tick_average_usec"] = divi(usec, std::max<int64_t>(1, ticks));
    m["steady_without_motor"] = steady_without_motor;
    m["steady_with_motor"] = steady_with_motor;
    state["last_events"] = events;
    state["last_step_metrics"] = m;
    Dictionary out;
    out["events"] = events;
    out["metrics"] = m;
    out["invariants"] = inv;
    auto presentation_capture = [](const std::vector<Body> &source, bool include_views, bool include_packed) {
      Array views;
      if (include_views)
        views.resize(source.size());
      PackedInt64Array packed;
      if (include_packed)
        packed = pack_presentation_bodies(source);
      int64_t feature_count = 0;
      for (int64_t i = 0; i < int64_t(source.size()); ++i) {
        const Body &q = source[size_t(i)];
        feature_count += q.kind != "coin";
        if (include_views) {
          Dictionary view;
          view["id"] = q.id;
          view["kind"] = q.kind;
          view["x"] = q.x;
          view["y"] = q.y;
          view["z"] = q.z;
          view["rest_state"] = q.rest;
          view["support_kind"] = q.support;
          view["support_root"] = q.support == "platform" || (q.support == "body" && q.carried)
                                     ? String("platform")
                                 : !q.support.is_empty() ? String("deck")
                                                         : String();
          views[i] = view;
        }
      }
      Dictionary capture;
      if (include_views)
        capture["views"] = views;
      if (include_packed)
        capture["packed"] = packed;
      capture["feature_count"] = feature_count;
      return capture;
    };
    if (capture_previous) {
      if (capture_previous_views) {
        Dictionary capture = presentation_capture(presentation_previous, true, false);
        out["presentation_previous_bodies"] = capture["views"];
      }
      if (capture_previous_packed)
        out["presentation_previous_packed"] = presentation_previous_packed;
      out["presentation_previous_face_y"] = presentation_previous_face_y;
      int64_t plate_block_count = 0, moving_under_face = 0;
      const int64_t current_face_y = int64_t(state.get("face_y", face_y(g, 0)));
      const int64_t face_delta = current_face_y - presentation_previous_face_y;
      if (presentation_previous_motion.size() == b.size()) {
        for (size_t i = 0; i < b.size(); ++i) {
          const PresentationMotionBody &before = presentation_previous_motion[i];
          const Body &current = b[i];
          if (before.id != current.id) {
            plate_block_count = moving_under_face = -1;
            break;
          }
          if (face_delta > 0 && before.support == "platform" && current.support == "platform" &&
              std::abs(current.y - (g.plate - g.coin_r)) <= 100 &&
              current.y - before.y < std::max<int64_t>(1, face_delta / 4))
            ++plate_block_count;
          if (face_delta < 0 && current.support == "deck" && current.y < before.y - 25 &&
              std::abs(current.y - current_face_y) <= 12000)
            ++moving_under_face;
        }
      } else {
        plate_block_count = moving_under_face = -1;
      }
      Dictionary motion;
      motion["valid"] = plate_block_count >= 0;
      motion["plate_block_count"] = std::max<int64_t>(0, plate_block_count);
      motion["moving_under_face"] = std::max<int64_t>(0, moving_under_face);
      out["presentation_motion"] = motion;
    }
    const bool capture_current_views = bool(config.get("capture_current_views", false));
    const bool capture_current_packed = bool(config.get("capture_current_packed", false));
    if (capture_current_views || capture_current_packed) {
      Dictionary capture = presentation_capture(b, capture_current_views, capture_current_packed);
      if (capture_current_views)
        out["presentation_current_bodies"] = capture["views"];
      if (capture_current_packed)
        out["presentation_current_packed"] = capture["packed"];
      out["presentation_feature_count"] = capture["feature_count"];
      out["presentation_current_face_y"] = int64_t(state.get("face_y", face_y(g, 0)));
    }
    return out;
  }
};

struct LiveKernelCache {
  String key;
  std::unique_ptr<Kernel> kernel;
};
} // namespace

bool CoinPusherNativeCore::can_step(const Dictionary &state,
                                    const Dictionary &) const {
  return String(state.get("schema", "")) == "coin_pusher_machine_v3" &&
         int64_t(state.get("version", 0)) == 3 &&
         Variant(state.get("bodies", Array())).get_type() == Variant::ARRAY;
}
Dictionary CoinPusherNativeCore::step_ticks(Dictionary state,
                                            const Dictionary &config,
                                            int64_t tick_count) const {
  String cache_key = config.get("live_cache_key", "");
  if (!cache_key.is_empty()) {
    static LiveKernelCache *live_cache = nullptr;
    bool reset = bool(config.get("live_cache_reset", false));
    if (!live_cache)
      live_cache = new LiveKernelCache;
    if (reset || !live_cache->kernel || live_cache->key != cache_key) {
      live_cache->key = cache_key;
      live_cache->kernel = std::make_unique<Kernel>(state, config, true);
      Dictionary result = live_cache->kernel->run(tick_count);
      live_cache->kernel->release_call_context();
      return result;
    }
    live_cache->kernel->resume(state, config);
    Dictionary result = live_cache->kernel->run(tick_count, false);
    live_cache->kernel->release_call_context();
    return result;
  }
  Kernel k(state, config);
  return k.run(tick_count);
}

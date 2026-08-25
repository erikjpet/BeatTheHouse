#include "coin_pusher_native_core.h"

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <limits>
#include <vector>

using namespace godot;

namespace {
constexpr int64_t FP = 1000, FIXED_HZ = 60, HARD_CEILING = 600, PASSES = 6;
constexpr int64_t GRAVITY = 1800, AIR_NUM = 61, AIR_DEN = 64, SLEEP_SPEED = 140,
                  SLEEP_TICKS = 5, HARD_IMPACT_SPEED = 12000;
constexpr int64_t SLOP = 60, BETA = 600, REST_BODY = 100, REST_PEG = 250,
                  MU_BODY = 500, MU_DECK = 700, MU_PLATFORM = 800;
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
  int64_t width = 100000, lip = 6000, deck = 0, top = 3600, extended = 28000,
          retracted = 46000, plate = 63000, plate_gap = 400, drop_y = 58000,
          drop_z = 24000, gutter = 3000, period = 240, ramp = 24, coin_r = 4300,
          coin_h = 1700, coin_m = 1000, coin_value = 1, jitter = 300,
          ceiling = 600;
  Array pegs;
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
  g.ceiling = clampi(d.get("ceiling", g.ceiling), 1, HARD_CEILING);
  g.pegs = a.get("pegs", Array());
  return g;
}
int64_t face_y(const Geo &g, int64_t phase) {
  int64_t i = posmod(phase, g.period);
  int64_t cosine = COS[(size_t)(i * (int64_t)COS.size() / g.period)];
  return g.extended + divi((g.retracted - g.extended) * (FP - cosine), 2 * FP);
}

struct Body {
  Dictionary ref, meta;
  String id, kind, rest, support, peg_key;
  int64_t x = 0, y = 0, z = 0, vx = 0, vy = 0, vz = 0, xr = 0, yr = 0, zr = 0,
          r = 4300, h = 1700, m = 1000, sleep_ticks = 0, fall_start_z = 0;
  bool sleeping = false, carried = false, plate_blocked = false,
       pending_deposit = false, has_fall_start = false, peg_contact = false;
};
bool z_overlap(const Body &l, const Body &r) {
  return l.z < r.z + r.h && r.z < l.z + l.h;
}
void wake(Body &b) {
  if (b.sleeping)
    b.sleep_ticks = 0;
  b.sleeping = false;
  b.carried = false;
  if (b.rest != "falling")
    b.rest = "settling";
}
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
  std::array<uint8_t, CAP> used{};
  std::vector<int> next;
  int slot(int64_t x, int64_t y, bool insert) {
    int s = (int)(((x * 73856093) ^ (y * 19349663)) & (CAP - 1));
    for (int p = 0; p < CAP; ++p) {
      if (!used[s]) {
        if (!insert)
          return -1;
        used[s] = 1;
        kx[s] = x;
        ky[s] = y;
        return s;
      }
      if (kx[s] == x && ky[s] == y)
        return s;
      s = (s + 1) & (CAP - 1);
    }
    return -1;
  }
  void rebuild(const std::vector<Body> &b) {
    used.fill(0);
    head.fill(0);
    next.assign(b.size(), 0);
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

struct Kernel {
  Dictionary state, config;
  Geo g;
  std::vector<Body> b;
  Array events;
  int64_t collisions = 0, candidate_peak = 0;
  bool energy_ok = true, conservation_ok = true;
  Kernel(Dictionary s, Dictionary c) : state(s), config(c), g(geometry(s)) {}
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
      q.support = r.get("support_kind", "");
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
          q.carried = false;
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
  void pegs() {
    for (Body &q : b)
      q.peg_contact = false;
    for (Body &q : b) {
      if (q.sleeping || std::abs(q.y - g.drop_y) > q.r)
        continue;
      if (q.rest != "falling") {
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
          // Full impacts retain the authored E=250 response.
          int64_t restitution = -rel < GRAVITY * 2 && !bool(q.meta.get("inserted", false)) ? 0 : REST_PEG;
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
        Dictionary e;
        e["kind"] = "peg_impact";
        e["body_id"] = q.id;
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
      q.peg_key = current_peg_key;
    }
  }
  std::vector<std::pair<int, int>> pairs(Grid &grid) {
    std::vector<std::pair<int, int>> p;
    std::vector<uint8_t> queued(b.size());
    std::array<int, 65536> seen;
    seen.fill(-1);
    std::vector<int> queue;
    auto first_seen = [&](int key) {
      int slot = key & (int(seen.size()) - 1);
      for (size_t probe = 0; probe < seen.size(); ++probe) {
        if (seen[slot] == key)
          return false;
        if (seen[slot] < 0) {
          seen[slot] = key;
          return true;
        }
        slot = (slot + 1) & (int(seen.size()) - 1);
      }
      return false;
    };
    for (int i = 0; i < (int)b.size(); ++i)
      if (!b[i].sleeping) {
        queued[i] = 1;
        queue.push_back(i);
      }
    for (size_t cursor = 0; cursor < queue.size(); ++cursor) {
      int i = queue[cursor];
      int64_t cx = floor_div(b[i].x, 10000), cy = floor_div(b[i].y, 10000);
      for (int oy = -1; oy <= 1; ++oy)
        for (int ox = -1; ox <= 1; ++ox)
          for (int j = grid.first(cx + ox, cy + oy); j >= 0;
               j = grid.after(j)) {
            if (i == j || !z_overlap(b[i], b[j]))
              continue;
            int64_t dx = b[j].x - b[i].x, dy = b[j].y - b[i].y,
                    mn = b[i].r + b[j].r;
            if (dx * dx + dy * dy >= mn * mn)
              continue;
            int lo = b[i].id <= b[j].id ? i : j,
                hi = b[i].id <= b[j].id ? j : i,
                key = std::min(i, j) * HARD_CEILING + std::max(i, j);
            if (first_seen(key) && p.size() < HARD_CEILING * 32)
              p.emplace_back(lo, hi);
            if (!queued[j]) {
              queued[j] = 1;
              queue.push_back(j);
            }
          }
    }
    std::sort(p.begin(), p.end(), [&](auto l, auto r) {
      return b[l.first].id < b[r.first].id || (b[l.first].id == b[r.first].id &&
                                               b[l.second].id < b[r.second].id);
    });
    return p;
  }
  bool contact(Body &l, Body &r) {
    if (!z_overlap(l, r))
      return false;
    int64_t dx = r.x - l.x, dy = r.y - l.y;
    if (dx == 0 && dy == 0)
      dx = l.id < r.id ? 1 : -1;
    int64_t mn = l.r + r.r, ds = dx * dx + dy * dy;
    if (ds >= mn * mn)
      return false;
    bool lawake = !l.sleeping, rawake = !r.sleeping;
    bool lmoving = std::abs(l.vx) + std::abs(l.vy) + std::abs(l.vz) >= SLEEP_SPEED;
    bool rmoving = std::abs(r.vx) + std::abs(r.vy) + std::abs(r.vz) >= SLEEP_SPEED;
    // A merely not-yet-asleep resting body must not perpetually wake an
    // overlapping sleeper. Only meaningful motion propagates an awake island.
    if (lawake && lmoving && !rawake)
      wake(r);
    else if (rawake && rmoving && !lawake)
      wake(l);
    int64_t d = std::max<int64_t>(1, isqrt(ds)), nx = divi(dx * FP, d),
            ny = divi(dy * FP, d),
            corr = divi(std::max<int64_t>(0, mn - d - SLOP) * BETA, FP),
            il = divi(FP * FP, l.m), ir = divi(FP * FP, r.m),
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
      wake(l);
      wake(r);
    }
    return true;
  }
  std::vector<int> static_candidates(const std::vector<uint8_t> &active,
                                     int64_t f) {
    std::vector<int> out;
    int64_t bottom = g.top + g.plate_gap;
    for (int i = 0; i < (int)b.size(); ++i)
      if (active[i]) {
        Body &q = b[i];
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
  int64_t resolve_supports(int64_t f, Grid &grid) {
    int64_t nestle_work = 0;
    for (int i = 0; i < (int)b.size(); ++i) {
      Body &q = b[i];
      if (q.sleeping)
        continue;
      String prev = q.pending_deposit ? String("platform") : q.support;
      int64_t surface_z = q.y >= f ? g.top : g.deck;
      String surface = q.y >= f ? String("platform") : String("deck");
      bool stable = q.z <= surface_z + SUPPORT_TOL;
      int64_t support_top = surface_z, count = 0, cx = 0, cy = 0;
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
            int64_t top = s.z + s.h;
            if (std::abs(q.z - top) > SUPPORT_TOL)
              continue;
            int64_t dx = s.x - q.x, dy = s.y - q.y,
                    reach = divi((q.r + s.r) * 9, 10);
            if (dx * dx + dy * dy >= reach * reach)
              continue;
            ++count;
            centered |= isqrt(dx * dx + dy * dy) < q.r / 2;
            xlo |= dx <= SUPPORT_MARGIN;
            xhi |= dx >= -SUPPORT_MARGIN;
            ylo |= dy <= SUPPORT_MARGIN;
            yhi |= dy >= -SUPPORT_MARGIN;
            cx += dx;
            cy += dy;
            bool carried = s.carried || s.support == "platform";
            if (top > support_top) {
              support_top = top;
              top_carried = carried;
            } else if (top == support_top)
              top_carried |= carried;
          }
      if (count) {
        stable |= centered || (xlo && xhi && ylo && yhi);
        if (!stable) {
          cx = divi(cx, count);
          cy = divi(cy, count);
          int64_t len = std::max<int64_t>(1, isqrt(cx * cx + cy * cy)),
                  before = body_energy(q);
          q.vx += divi(cx * GRAVITY, 2 * len);
          q.vy += divi(cy * GRAVITY, 2 * len);
          nestle_work += std::max<int64_t>(0, body_energy(q) - before);
        }
      }
      if (stable && q.vz <= 0) {
        bool falling = q.rest == "falling";
        int64_t fall_start = q.has_fall_start ? q.fall_start_z : q.z;
        int64_t impact_speed = std::abs(q.vz);
        q.z = support_top;
        q.vz = 0;
        q.zr = 0;
        q.support = support_top == surface_z ? surface : "body";
        q.carried =
            q.support == "platform" || (q.support == "body" && top_carried);
        q.rest = "resting";
        friction(q, q.support == "platform" ? MU_PLATFORM : MU_DECK);
        if (falling) {
          Dictionary e;
          e["kind"] = "impact";
          e["body_id"] = q.id;
          e["support"] = q.support;
          e["support_root"] = q.support == "platform" || (q.support == "body" && top_carried) ? String("platform") : String("deck");
          bool first_support = bool(q.meta.get("inserted", false)) && !bool(q.meta.get("first_support_recorded", false));
          e["first_support"] = first_support;
          e["fall_height"] = std::max<int64_t>(0, fall_start - support_top);
          e["impact_speed"] = impact_speed;
          e["impact_class"] = impact_speed >= HARD_IMPACT_SPEED ? String("hard") : String("soft");
          e["stack_depth"] = std::max<int64_t>(
              0, divi(support_top - surface_z, std::max<int64_t>(1, q.h)));
          events.append(e);
          if (first_support)
            q.meta["first_support_recorded"] = true;
          q.has_fall_start = false;
        }
      } else {
        if (q.rest != "falling") {
          q.fall_start_z = q.z;
          q.has_fall_start = true;
        }
        if (prev == "platform")
          q.pending_deposit = true;
        q.support = "";
        q.carried = false;
        q.rest = "falling";
        q.sleep_ticks = 0;
        q.sleeping = false;
      }
      if (prev == "platform" && q.support == "deck") {
        Dictionary e;
        e["kind"] = "platform_deposit";
        e["body_id"] = q.id;
        events.append(e);
        q.pending_deposit = false;
      }
    }
    return nestle_work;
  }
  void exits() {
    for (int i = (int)b.size() - 1; i >= 0; --i) {
      Body &q = b[i];
      String outcome;
      if (q.y - q.r < g.lip)
        outcome = (q.x >= g.gutter && q.x <= g.width - g.gutter)
                      ? String("tray")
                      : String("gutter");
      else if (q.x + q.r < g.gutter || q.x - q.r > g.width - g.gutter)
        outcome = "gutter";
      if (outcome.is_empty())
        continue;
      Dictionary e;
      e["body_id"] = q.id;
      e["kind"] = q.kind;
      e["value"] = q.meta.get("value", q.kind == "coin" ? 1 : 0);
      e["item_id"] = q.meta.get("item_id", "");
      e["provenance"] = q.meta.get("provenance", Dictionary());
      Array ledger = state.get(
          outcome == "tray" ? "tray_ledger" : "gutter_ledger", Array());
      ledger.append(e);
      state[outcome == "tray" ? "tray_ledger" : "gutter_ledger"] = ledger;
      Dictionary ev;
      ev["kind"] = outcome;
      ev["outcome"] = outcome;
      ev["body_id"] = q.id;
      ev["body_kind"] = q.kind;
      ev["x"] = q.x;
      ev["radius"] = q.r;
      ev["height"] = q.h;
      ev["mass"] = q.m;
      ev["tick"] = state.get("tick", 0);
      ev["stroke_cycle"] = state.get("stroke_cycle_serial", 0);
      ev["phase_fp"] = state.get("phase_fp", 0);
      ev["metadata"] = q.meta.duplicate(true);
      events.append(ev);
      b.erase(b.begin() + i);
    }
  }
  void nudge(int64_t x, int64_t y) {
    for (Body &q : b) {
      q.vx += divi(x * FP, q.m);
      q.vy += divi(y * FP, q.m);
      wake(q);
    }
  }
  void add_drop(Object *rng, int64_t x, int64_t density,
                const Dictionary &provenance = Dictionary()) {
    if ((int64_t)b.size() >= g.ceiling) {
      state["refused_inserts"] = int64_t(state.get("refused_inserts", 0)) + 1;
      Dictionary e;
      e["kind"] = "insert_refused";
      e["reason"] = "ceiling";
      e["returned"] = true;
      events.append(e);
      return;
    }
    std::vector<int64_t> legal_offsets;
    Array pegs = g.pegs;
    for (int64_t offset = -g.jitter; offset <= g.jitter; ++offset) {
      int64_t candidate = clampi(x + offset, g.coin_r, g.width - g.coin_r);
      bool exact_symmetry = false;
      for (int peg_index = 0; peg_index < pegs.size(); ++peg_index) {
        Dictionary peg = pegs[peg_index];
        if (candidate == int64_t(peg.get("x", candidate + 1))) {
          exact_symmetry = true;
          break;
        }
      }
      if (!exact_symmetry)
        legal_offsets.push_back(offset);
    }
    int64_t jitter = 0;
    if (rng && !legal_offsets.empty()) {
      int64_t selected = int64_t(rng->call(
          "randi_range", 0, int64_t(legal_offsets.size()) - 1));
      jitter = legal_offsets[selected];
    }
    Body q;
    int64_t next_id = state.get("next_body_id", 1);
    q.id = String("body_") + String::num_int64(next_id).pad_zeros(5);
    state["next_body_id"] = next_id + 1;
    q.kind = "coin";
    q.x = clampi(x + jitter, g.coin_r, g.width - g.coin_r);
    q.y = g.drop_y;
    q.z = g.drop_z;
    q.fall_start_z = q.z;
    q.has_fall_start = true;
    q.r = g.coin_r;
    q.h = g.coin_h;
    q.m = g.coin_m * std::max<int64_t>(1, density);
    q.rest = "falling";
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
                 in.get("density", 1), in.get("provenance", Dictionary()));
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
      a.append(r);
    }
    state["bodies"] = a;
  }
  Dictionary run(int64_t ticks) {
    auto start = std::chrono::steady_clock::now();
    if (!load() || ticks < 0)
      return Dictionary();
    Array trace = config.get("input_trace", Array());
    int64_t cursor = 0;
    Grid grid;
    for (int64_t t = 0; t < ticks; ++t) {
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
      int64_t platform_work = std::max<int64_t>(0, energy() - before),
              gravity_before = energy();
      integrate();
      int64_t gravity_work = std::max<int64_t>(0, energy() - gravity_before);
      pegs();
      grid.rebuild(b);
      int64_t nestle_work = resolve_supports(newf, grid);
      grid.rebuild(b);
      auto ps = pairs(grid);
      candidate_peak = std::max<int64_t>(candidate_peak, ps.size());
      std::vector<uint8_t> active(b.size());
      for (size_t i = 0; i < b.size(); ++i)
        active[i] = !b[i].sleeping;
      bool changed = true;
      while (changed) {
        changed = false;
        for (auto p : ps)
          if (active[p.first] != active[p.second]) {
            active[p.first] = active[p.second] = 1;
            changed = true;
          }
      }
      auto statics = static_candidates(active, newf);
      for (int pass = 0; pass < PASSES; ++pass) {
        for (auto p : ps)
          if ((active[p.first] || active[p.second]) &&
              contact(b[p.first], b[p.second]))
            ++collisions;
        platform_work += static_contacts(statics, newf, delta);
      }
      grid.rebuild(b);
      nestle_work += resolve_supports(newf, grid);
      for (Body &q : b)
        if (!q.sleeping && q.rest == "resting" && !q.support.is_empty())
          update_sleep(q);
      exits();
      state["tick"] = int64_t(state.get("tick", 0)) + 1;
      energy_ok &=
          energy() <= before + platform_work + gravity_work + nestle_work;
      int64_t tick_tray = Array(state.get("tray_ledger", Array())).size();
      int64_t tick_gutter = Array(state.get("gutter_ledger", Array())).size();
      int64_t tick_collected = int64_t(state.get("collected_count", 0));
      int64_t tick_origin = int64_t(state.get("opening_body_count", 0)) +
                            int64_t(state.get("accepted_inserts", 0)) +
                            int64_t(state.get("external_origin_count", 0));
      conservation_ok &=
          int64_t(b.size()) + tick_tray + tick_gutter + tick_collected == tick_origin;
    }
    write();
    int64_t active = b.size(),
            tray = Array(state.get("tray_ledger", Array())).size(),
            gutter = Array(state.get("gutter_ledger", Array())).size(),
            collected = int64_t(state.get("collected_count", 0)),
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
    inv["origin"] = origin;
    inv["refused"] = state.get("refused_inserts", 0);
    state["last_invariants"] = inv;
    int64_t awake = 0;
    for (const Body &q : b)
      awake += !q.sleeping;
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
    state["last_events"] = events;
    state["last_step_metrics"] = m;
    Dictionary out;
    out["events"] = events;
    out["metrics"] = m;
    out["invariants"] = inv;
    return out;
  }
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
  Kernel k(state, config);
  return k.run(tick_count);
}

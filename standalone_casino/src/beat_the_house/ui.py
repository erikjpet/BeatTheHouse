from __future__ import annotations

import tkinter as tk
from tkinter import messagebox

from beat_the_house.games import CasinoGame, build_games_for_floor
from beat_the_house.progression import (
    MetaStore,
    buy_upgrade,
    create_run,
    evaluate_meta_unlocks,
    offer_shop,
)


class BeatTheHouseApp:
    def __init__(self) -> None:
        self.store = MetaStore()
        self.meta = self.store.load()
        self.state = None
        self.games: list[CasinoGame] = []

        self.root = tk.Tk()
        self.root.title("Beat The House")
        self.root.geometry("780x520")
        self.root.minsize(680, 460)
        self.root.configure(bg="#111")

        self.header_text = tk.StringVar(value="")
        self.status_text = tk.StringVar(value="Press Start Run to begin.")
        self.meta_text = tk.StringVar(value="")

        self._build_layout()
        self._render_meta()

    def _build_layout(self) -> None:
        title = tk.Label(
            self.root,
            text="Beat The House",
            font=("Arial", 22, "bold"),
            fg="#f4d35e",
            bg="#111",
        )
        title.pack(pady=(14, 4))

        tk.Label(self.root, textvariable=self.meta_text, fg="#ddd", bg="#111").pack()
        tk.Button(self.root, text="Start Run", command=self.start_run).pack(pady=10)

        self.header_label = tk.Label(
            self.root,
            textvariable=self.header_text,
            justify="left",
            anchor="w",
            fg="#cde",
            bg="#1b1b1b",
            width=90,
            height=3,
            padx=10,
            pady=6,
        )
        self.header_label.pack(fill="x", padx=16)

        main_area = tk.Frame(self.root, bg="#111")
        main_area.pack(fill="both", expand=True, padx=16, pady=12)

        left = tk.Frame(main_area, bg="#111")
        left.pack(side="left", fill="both", expand=True)

        control_row = tk.Frame(left, bg="#111")
        control_row.pack(anchor="w", pady=(0, 8))

        tk.Label(control_row, text="Wager:", fg="#ddd", bg="#111").pack(side="left")
        self.wager = tk.IntVar(value=1)
        self.wager_spin = tk.Spinbox(
            control_row,
            from_=1,
            to=25,
            textvariable=self.wager,
            width=6,
        )
        self.wager_spin.pack(side="left", padx=8)

        self.shop_button = tk.Button(control_row, text="Shop", command=self.open_shop, state="disabled")
        self.shop_button.pack(side="left", padx=8)

        self.cashout_button = tk.Button(control_row, text="Cash Out", command=self.cash_out, state="disabled")
        self.cashout_button.pack(side="left")

        self.next_floor_button = tk.Button(
            control_row,
            text="Advance Floor",
            command=self.advance_floor,
            state="disabled",
        )
        self.next_floor_button.pack(side="left", padx=8)

        self.game_frame = tk.Frame(left, bg="#111")
        self.game_frame.pack(fill="x", anchor="w")

        right = tk.Frame(main_area, bg="#111")
        right.pack(side="right", fill="both", expand=True)

        tk.Label(right, text="Run Log", fg="#ddd", bg="#111", font=("Arial", 11, "bold")).pack(anchor="w")
        self.log = tk.Text(right, height=18, width=48, bg="#1b1b1b", fg="#eee", wrap="word")
        self.log.pack(fill="both", expand=True)
        self.log.configure(state="disabled")

        tk.Label(self.root, textvariable=self.status_text, fg="#89d", bg="#111").pack(anchor="w", padx=16, pady=(0, 10))

    def _render_meta(self) -> None:
        self.meta_text.set(
            f"Runs: {self.meta.total_runs} | Max floor: {self.meta.max_floor_reached} | Prestige: {self.meta.prestige_tokens}"
        )

    def _append_log(self, line: str) -> None:
        self.log.configure(state="normal")
        self.log.insert("end", line + "\n")
        self.log.see("end")
        self.log.configure(state="disabled")

    def start_run(self) -> None:
        self.state = create_run(self.meta)
        self._append_log("\n=== New run started ===")
        self.shop_button.configure(state="normal")
        self.cashout_button.configure(state="normal")
        self.next_floor_button.configure(state="normal")
        self._refresh_floor()

    def _refresh_floor(self) -> None:
        if self.state is None:
            return
        self.games = build_games_for_floor(self.state.floor)

        for widget in self.game_frame.winfo_children():
            widget.destroy()

        tk.Label(self.game_frame, text="Choose game:", fg="#ddd", bg="#111").pack(anchor="w", pady=(0, 4))
        for game in self.games:
            tk.Button(
                self.game_frame,
                text=game.name.replace("_", " ").title(),
                width=16,
                command=lambda g=game: self.play_game(g),
            ).pack(anchor="w", pady=2)

        self._refresh_header()

    def _refresh_header(self) -> None:
        if self.state is None:
            return
        self.header_text.set(
            f"Floor {self.state.floor}  |  Bankroll ${self.state.bankroll}  |  Heat {self.state.heat}/{self.state.suspicion_limit}  |  Actions {self.state.day_actions_left}"
        )
        max_wager = max(1, min(25, self.state.bankroll))
        self.wager_spin.configure(to=max_wager)
        if self.wager.get() > max_wager:
            self.wager.set(max_wager)

    def play_game(self, game: CasinoGame) -> None:
        if self.state is None or self.state.day_actions_left <= 0:
            self.status_text.set("No actions left. Visit shop or move floors.")
            return

        wager = max(1, min(self.wager.get(), self.state.bankroll))
        result = game.play(self.state, wager)
        self.state.update_bankroll(result.bankroll_delta)
        self.state.add_heat(result.heat_delta)
        self.state.spend_action()

        self._append_log(
            f"[{game.name}] {result.summary} | Δ${result.bankroll_delta} | +{result.heat_delta} heat"
        )

        if self.state.busted():
            self._end_run("You were caught or went broke.")
            return

        if self.state.day_actions_left == 0:
            self.status_text.set("Day over. Open shop, then advance floor or cash out.")
        else:
            self.status_text.set("Choose your next move.")

        self._refresh_header()

    def open_shop(self) -> None:
        if self.state is None:
            return

        offers = offer_shop(self.state, self.meta)
        if not offers:
            self.status_text.set("No upgrades unlocked yet.")
            return

        popup = tk.Toplevel(self.root)
        popup.title("Black-Market Shop")
        popup.configure(bg="#111")

        tk.Label(popup, text=f"Bankroll: ${self.state.bankroll}", fg="#ddd", bg="#111").pack(anchor="w", padx=12, pady=8)

        def buy(idx: int) -> None:
            item = offers[idx]
            if buy_upgrade(self.state, item):
                self._append_log(f"Bought upgrade: {item.name}")
                self.status_text.set(f"Purchased {item.name}.")
            else:
                self.status_text.set("Not enough bankroll.")
            self._refresh_header()
            popup.destroy()

        for idx, item in enumerate(offers):
            row = tk.Frame(popup, bg="#111")
            row.pack(fill="x", padx=12, pady=4)
            perm = "perm" if item.permanent else "temp"
            tk.Label(
                row,
                text=f"{item.name} (${item.cost}, {perm}) - {item.description}",
                fg="#ddd",
                bg="#111",
                wraplength=430,
                justify="left",
            ).pack(side="left")
            tk.Button(row, text="Buy", command=lambda i=idx: buy(i)).pack(side="right")

        tk.Button(popup, text="Close", command=popup.destroy).pack(pady=(4, 10))

    def cash_out(self) -> None:
        if self.state is None:
            return
        self._end_run("You cashed out.")

    def advance_floor(self) -> None:
        if self.state is None:
            return
        target = 100 * self.state.floor
        if self.state.bankroll < target:
            self.status_text.set(f"Need ${target} bankroll to advance.")
            return
        self.state.floor += 1
        self.state.day_actions_left = 8
        self.state.heat = max(0, self.state.heat - 20)
        self._append_log(f"Advanced to floor {self.state.floor}.")
        self.status_text.set("New floor reached.")
        self._refresh_floor()

    def _end_run(self, reason: str) -> None:
        if self.state is None:
            return

        evaluate_meta_unlocks(self.meta, self.state.floor, self.state.bankroll)
        self.store.save(self.meta)
        self._render_meta()
        self.status_text.set(f"Run ended: {reason}")
        self._append_log(
            f"Run complete: floor {self.state.floor}, bankroll ${self.state.bankroll}."
        )
        messagebox.showinfo("Run Complete", f"{reason}\nFloor: {self.state.floor}\nBankroll: ${self.state.bankroll}")
        self.state = None
        self.header_text.set("Start another run when ready.")
        self.shop_button.configure(state="disabled")
        self.cashout_button.configure(state="disabled")
        self.next_floor_button.configure(state="disabled")

    def run(self) -> None:
        self.root.mainloop()


def launch_ui() -> None:
    app = BeatTheHouseApp()
    app.run()

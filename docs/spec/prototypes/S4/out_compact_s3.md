Thresholds: Uncommon >= 0.50, Rare >= 0.72, Epic >= 0.92; cap rule max; score model s3; N = 20000 crafts per cell
| Player | Plan (Smelt / Ham / Sharp) | Iron C / U / R / E % | Iron mean Q | Steel C / U / R / E % | Steel mean Q | crafts with a fail % (Iron / Steel) |
|---|---|---|---:|---|---:|---|
| Poor | All-Normal | 6 / 92 / 2 / 0 | 0.61 | 8 / 86 / 6 / 0 | 0.61 | 21 / 47 |
| Poor | Mixed-1 (Sharp H) | 10 / 84 / 6 / 0 | 0.60 | 16 / 76 / 8 / 0 | 0.59 | 56 / 81 |
| Poor | Mixed-2 (Ham+Sharp H) | 22 / 69 / 9 / 0 | 0.59 | 28 / 64 / 8 / 0 | 0.57 | 74 / 91 |
| Poor | All-Hard | 20 / 69 / 11 / 0 | 0.59 | 23 / 68 / 9 / 0 | 0.58 | 77 / 92 |
| Good | All-Normal | 0 / 0 / 100 / 0 | 0.84 | 0 / 0 / 100 / 0 | 0.89 | 0 / 0 |
| Good | Mixed-1 (Sharp H) | 0 / 0 / 78 / 22 | 0.90 | 0 / 0 / 20 / 80 | 0.95 | 0 / 0 |
| Good | Mixed-2 (Ham+Sharp H) | 0 / 0 / 33 / 67 | 0.94 | 0 / 0 / 6 / 94 | 0.99 | 0 / 0 |
| Good | All-Hard | 0 / 0 / 24 / 76 | 0.95 | 0 / 0 / 4 / 96 | 1.01 | 0 / 0 |
| Elite | All-Normal | 0 / 0 / 100 / 0 | 0.95 | 0 / 0 / 100 / 0 | 1.03 | 0 / 0 |
| Elite | Mixed-1 (Sharp H) | 0 / 0 / 0 / 100 | 1.02 | 0 / 0 / 0 / 100 | 1.11 | 0 / 0 |
| Elite | Mixed-2 (Ham+Sharp H) | 0 / 0 / 0 / 100 | 1.10 | 0 / 0 / 0 / 100 | 1.20 | 0 / 0 |
| Elite | All-Hard | 0 / 0 / 0 / 100 | 1.13 | 0 / 0 / 0 / 100 | 1.22 | 0 / 0 |

target check:
  good N iron: R >= 55%        margin +0.450 OK
  good H iron: E >= 5%         margin +0.710 OK
  good H iron: E <= 45%        margin -0.310 FAIL

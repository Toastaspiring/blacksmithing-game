Thresholds: Uncommon >= 0.50, Rare >= 0.72, Epic >= 0.92; cap rule max; score model s4; N = 20000 crafts per cell
| Player | Plan (Smelt / Ham / Sharp) | Iron C / U / R / E % | Iron mean Q | Steel C / U / R / E % | Steel mean Q | crafts with a fail % (Iron / Steel) |
|---|---|---|---:|---|---:|---|
| Bad | All-Normal | 93 / 7 / 0 / 0 | 0.33 | 93 / 7 / 0 / 0 | 0.33 | 97 / 99 |
| Bad | Mixed-1 (Sharp H) | 96 / 4 / 0 / 0 | 0.30 | 96 / 4 / 0 / 0 | 0.30 | 99 / 100 |
| Bad | Mixed-2 (Ham+Sharp H) | 98 / 2 / 0 / 0 | 0.27 | 98 / 2 / 0 / 0 | 0.27 | 100 / 100 |
| Bad | All-Hard | 99 / 1 / 0 / 0 | 0.24 | 99 / 1 / 0 / 0 | 0.23 | 100 / 100 |
| Average | All-Normal | 21 / 74 / 6 / 0 | 0.58 | 20 / 67 / 13 / 0 | 0.60 | 42 / 56 |
| Average | Mixed-1 (Sharp H) | 30 / 64 / 6 / 0 | 0.56 | 30 / 59 / 11 / 0 | 0.57 | 70 / 80 |
| Average | Mixed-2 (Ham+Sharp H) | 42 / 52 / 6 / 0 | 0.53 | 40 / 51 / 9 / 0 | 0.54 | 84 / 90 |
| Average | All-Hard | 49 / 45 / 6 / 0 | 0.51 | 49 / 44 / 7 / 0 | 0.51 | 90 / 95 |
| Good | All-Normal | 0 / 26 / 74 / 0 | 0.76 | 0 / 11 / 89 / 0 | 0.80 | 1 / 2 |
| Good | Mixed-1 (Sharp H) | 0 / 20 / 78 / 2 | 0.77 | 0 / 12 / 79 / 9 | 0.81 | 5 / 10 |
| Good | Mixed-2 (Ham+Sharp H) | 0 / 17 / 79 / 4 | 0.79 | 0 / 13 / 72 / 14 | 0.83 | 9 / 17 |
| Good | All-Hard | 0 / 15 / 77 / 8 | 0.81 | 0 / 13 / 66 / 21 | 0.84 | 12 / 23 |
| Excellent | All-Normal | 0 / 0 / 100 / 0 | 0.88 | 0 / 0 / 100 / 0 | 0.93 | 0 / 0 |
| Excellent | Mixed-1 (Sharp H) | 0 / 0 / 53 / 47 | 0.92 | 0 / 0 / 18 / 82 | 0.97 | 0 / 0 |
| Excellent | Mixed-2 (Ham+Sharp H) | 0 / 0 / 27 / 73 | 0.95 | 0 / 0 / 6 / 94 | 1.01 | 0 / 0 |
| Excellent | All-Hard | 0 / 0 / 12 / 88 | 0.99 | 0 / 0 / 2 / 98 | 1.05 | 0 / 0 |

target check:
  avg N iron: C+U >= 90%       margin +0.042 OK
  avg N iron: U >= 55%         margin +0.186 OK
  avg N steel: R <= 25%        margin +0.117 OK
  bad N iron: C >= 70%         margin +0.231 OK
  good N iron: R >= 55%        margin +0.194 OK
  exc N iron: R >= 90%         margin +0.100 OK
  avg H iron: E <= 2%          margin +0.020 OK
  avg H steel: E <= 2%         margin +0.019 OK
  good H iron: E >= 5%         margin +0.031 OK
  good H iron: E <= 45%        margin +0.369 OK
  exc H iron: E >= 60%         margin +0.285 OK
  exc 1xH iron: E <= 60%       margin +0.134 OK

"""Sinh bộ dữ liệu raw tuần 3 cho Finova Onboarding (schema luyen_tap_w3).

Năm bảng giữ đúng cột của tuần 1 (customers, accounts, branches, instruments, orders),
thêm hai bảng mới: cash_txn (giao dịch tiền) và position_daily (số dư chứng khoán cuối ngày).
Toàn bộ là dữ liệu mô phỏng, seed cố định nên chạy lại cho cùng kết quả.
Đầu ra: một file SQL (DDL + INSERT) chạy được bằng psql hoặc DBeaver.
"""
import random
import datetime as dt
from decimal import Decimal, ROUND_HALF_UP
from collections import defaultdict

R = random.Random(20261005)
SCHEMA = "luyen_tap_w3"
ICT = dt.timezone(dt.timedelta(hours=7))
OUT = "w3_raw_luyen_tap_w3.sql"

# ---------------- Lịch giao dịch ----------------
def trading_days(start, end):
    d, out = start, []
    while d <= end:
        if d.weekday() < 5:
            out.append(d)
        d += dt.timedelta(days=1)
    return out

DAYS = trading_days(dt.date(2026, 3, 2), dt.date(2026, 3, 27))          # 20 phiên
assert len(DAYS) == 20
OPEN_DAY = dt.date(2026, 2, 27)                                          # ngày chụp số dư đầu kỳ
CAL = trading_days(dt.date(2026, 2, 23), dt.date(2026, 4, 10))
def t_plus(d, n):
    i = CAL.index(d)
    return CAL[i + n]
def prev_td(d):
    return CAL[CAL.index(d) - 1]

# ---------------- Chi nhánh ----------------
BRANCHES = [
    ("HO", "Hội sở", None),
    ("MB", "Khu vực miền Bắc", "HO"),
    ("MT", "Khu vực miền Trung", "HO"),
    ("MN", "Khu vực miền Nam", "HO"),
    ("HN01", "Chi nhánh Hà Nội 1", "MB"),
    ("HN02", "Chi nhánh Hà Nội 2", "MB"),
    ("HP01", "PGD Hải Phòng", "HN02"),
    ("DN01", "Chi nhánh Đà Nẵng", "MT"),
    ("HCM01", "Chi nhánh TP.HCM 1", "MN"),
    ("HCM02", "Chi nhánh TP.HCM 2", "MN"),
    ("CT01", "Chi nhánh Cần Thơ", "MN"),
]
LEAF = ["HN01", "HN02", "HP01", "DN01", "HCM01", "HCM02", "CT01"]
LEAF_W = [6, 9, 4, 4, 8, 6, 3]

# ---------------- Mã chứng khoán ----------------
SECTOR = {
    "Financials": ["ACB", "BID", "CTG", "MBB", "SSI", "STB", "TCB", "VCB", "VPB", "HDB", "TPB", "VIB", "BVH"],
    "Information Technology": ["FPT"],
    "Materials": ["HPG", "DGC", "GVR"],
    "Consumer Staples": ["MSN", "VNM", "SAB"],
    "Consumer Discretionary": ["MWG", "PNJ"],
    "Real Estate": ["VHM", "VIC", "KDH", "NLG"],
    "Utilities": ["GAS", "POW", "REE"],
    "Energy": ["PLX"],
    "Industrials": ["VJC"],
}
SYM_SECTOR = {s: k for k, v in SECTOR.items() for s in v}
TRADED = ["ACB", "BID", "CTG", "FPT", "HPG", "MBB", "MSN", "MWG", "SSI", "STB",
          "TCB", "VCB", "VHM", "VIC", "VNM", "VPB", "GAS", "PLX", "POW", "REE"]
BASE = {"ACB": 25000, "BID": 45000, "CTG": 35000, "FPT": 120000, "HPG": 27000, "MBB": 23000,
        "MSN": 75000, "MWG": 60000, "SSI": 30000, "STB": 35000, "TCB": 25000, "VCB": 90000,
        "VHM": 45000, "VIC": 45000, "VNM": 65000, "VPB": 19000, "GAS": 70000, "PLX": 40000,
        "POW": 12000, "REE": 65000, "XYZ": 15000}
ALL_SYMS = sorted(SYM_SECTOR)
assert len(ALL_SYMS) == 31

def tick(p):
    step = 10 if p < 10000 else (50 if p < 50000 else 100)
    return int(round(p / step) * step)

# giá tham chiếu theo ngày (random walk)
DAYPX = {}
for s, b in BASE.items():
    p = b
    for d in DAYS:
        p = p * (1 + R.uniform(-0.02, 0.02))
        DAYPX[(s, d)] = tick(p)

# ---------------- Khách hàng & tài khoản ----------------
SEGS = ["MASS", "AFFLUENT", "VIP"]
customers = [f"LTC{i:03d}" for i in range(1, 31)]
n_acc = {c: 1 for c in customers}
for c in customers[2:8]:
    n_acc[c] = 2
for c in ["LTC011", "LTC024"]:
    n_acc[c] = 3
assert sum(n_acc.values()) == 40

accounts = []
k = 1
for c in customers:
    for j in range(n_acc[c]):
        br = R.choices(LEAF, LEAF_W)[0]
        accounts.append({
            "account_id": f"LTA{k:03d}", "customer_id": c, "branch_code": br,
            "account_type": "KYQUY" if R.random() < 0.3 else "THUONG",
            "open_date": dt.date(2022, 1, 1) + dt.timedelta(days=R.randint(0, 1400)),
        })
        k += 1
# đảm bảo khách nhiều tài khoản có ít nhất một cặp khác chi nhánh
acc_by_c = defaultdict(list)
for a in accounts:
    acc_by_c[a["customer_id"]].append(a)
for c in ["LTC003", "LTC011", "LTC024"]:
    acc_by_c[c][-1]["branch_code"] = "HCM01" if acc_by_c[c][0]["branch_code"] != "HCM01" else "HN02"

# phiên bản khách hàng: phiên bản đầu, thay đổi, bẫy
cust_rows = []
first_date = {}
for i, c in enumerate(customers):
    # bẫy: một nửa khách có phiên bản đầu sau 02/03 → lệnh sớm không tìm được phiên bản
    fd = dt.date(2026, 2, 20) + dt.timedelta(days=R.randint(0, 6)) if i % 2 == 0 \
        else dt.date(2026, 3, 2) + dt.timedelta(days=R.randint(0, 8))
    first_date[c] = fd
    seg = R.choices(SEGS, [6, 3, 1])[0]
    cust_rows.append([c, seg, "VERIFIED" if R.random() < 0.85 else "PENDING", fd])
by_c = defaultdict(list)
for r in cust_rows:
    by_c[r[0]].append(r)
# 9 khách đổi segment một lần
chg = ["LTC002", "LTC005", "LTC007", "LTC010", "LTC013", "LTC016", "LTC019", "LTC022", "LTC027"]
for c in chg:
    last = by_c[c][-1]
    newseg = R.choice([s for s in SEGS if s != last[1]])
    d = max(last[3] + dt.timedelta(days=3), dt.date(2026, 3, 9)) + dt.timedelta(days=R.randint(0, 9))
    r = [c, newseg, last[2], d]
    by_c[c].append(r)
# A → B → A cho LTC008
last = by_c["LTC008"][-1]
other = "AFFLUENT" if last[1] != "AFFLUENT" else "MASS"
by_c["LTC008"].append(["LTC008", other, last[2], dt.date(2026, 3, 11)])
by_c["LTC008"].append(["LTC008", last[1], last[2], dt.date(2026, 3, 20)])
# 3 khách chỉ đổi kyc_status
for c in ["LTC004", "LTC014", "LTC025"]:
    last = by_c[c][-1]
    by_c[c].append([c, last[1], "EXPIRED" if last[2] == "VERIFIED" else "VERIFIED",
                    max(last[3] + dt.timedelta(days=5), dt.date(2026, 3, 12)) + dt.timedelta(days=R.randint(0, 6))])
# bẫy: một dòng trùng hoàn toàn (nạp lại cùng nội dung)
dup = list(by_c["LTC016"][0])
by_c["LTC016"].insert(1, dup)
cust_all = [r for c in customers for r in by_c[c]]

# ---------------- Lệnh ----------------
active = [a["account_id"] for a in accounts]
R.shuffle(active)
inactive = set(active[:5])                 # 5 tài khoản không có lệnh
active = [a for a in active if a not in inactive]
assert len(active) == 35
weights = {a: R.choice([1, 1, 2, 3, 5, 8]) for a in active}
# mỗi tài khoản giao dịch một tập mã riêng
acc_syms = {a: R.sample(TRADED, R.randint(4, 12)) for a in active}

orders = []
n = 0
TOTAL = 2000
per_day = [TOTAL // 20] * 20
for i in range(TOTAL - sum(per_day)):
    per_day[i] += 1
xyz_slots = {(7, 3), (12, 10), (15, 22)}      # bẫy mã mồ côi XYZ
STATUS = ["Filled", "Partial", "Cancelled", "Rejected"]
for di, d in enumerate(DAYS):
    for j in range(per_day[di]):
        n += 1
        a = R.choices(active, [weights[x] for x in active])[0]
        s = "XYZ" if (di, j) in xyz_slots else R.choice(acc_syms[a])
        side = "B" if R.random() < 0.52 else "S"
        q = R.choice([100, 200, 300, 500, 500, 1000, 1000, 1500, 2000, 3000, 5000])
        px = tick(DAYPX[(s, d)] * (1 + R.uniform(-0.01, 0.01)))
        st = R.choices(STATUS, [65, 10, 15, 10])[0]
        if (di, j) == (12, 10):
            st = "Cancelled"
        elif (di, j) in xyz_slots:
            st = "Filled"
        # giờ đặt lệnh: phần lớn trong phiên; ~1% lệnh đặt trước lúc 06:xx (bẫy múi giờ)
        if R.random() < 0.012:
            hh, mm = 6, R.randint(0, 59)
        else:
            mins = R.randint(0, 5 * 60 + 45)       # 09:00 → 14:45
            if 150 <= mins < 240:                  # bỏ giờ nghỉ trưa 11:30–13:00
                mins += 90
            mins = min(mins, 5 * 60 + 45)
            hh, mm = 9 + mins // 60, mins % 60
        ts = dt.datetime(d.year, d.month, d.day, hh, mm, R.randint(0, 59), tzinfo=ICT)
        orders.append({"order_id": f"LTO{n:05d}", "account_id": a, "symbol": s, "side": side,
                       "quantity": q, "price": px, "order_ts": ts, "status": st})
orders.sort(key=lambda o: (o["order_ts"], o["order_id"]))

def tdate(o):
    return o["order_ts"].astimezone(ICT).date()

filled = [o for o in orders if o["status"] == "Filled"]

# ---------------- position_daily ----------------
pair_orders = defaultdict(list)
for o in filled:
    pair_orders[(o["account_id"], o["symbol"])].append(o)
opening = {}
for pair, lst in pair_orders.items():
    cum, mn = 0, 0
    for o in lst:
        cum += o["quantity"] if o["side"] == "B" else -o["quantity"]
        mn = min(mn, cum)
    need = -mn
    extra = R.choice([0, 0, 0, 100, 500, 1000, 2000])
    opening[pair] = int((need + extra + 99) // 100 * 100)

last_px = {}
first_fill_px = {}
for o in filled:
    first_fill_px.setdefault(o["symbol"], o["price"])
close_px = {}
for d in [OPEN_DAY] + DAYS:
    for s in BASE:
        day_fills = [o for o in filled if o["symbol"] == s and tdate(o) == d]
        if day_fills:
            last_px[s] = day_fills[-1]["price"]
        close_px[(s, d)] = last_px.get(s, first_fill_px.get(s, BASE[s]))

positions = []
for pair, lst in sorted(pair_orders.items()):
    a, s = pair
    qty = opening[pair]
    snap = [OPEN_DAY] + DAYS
    for d in snap:
        if d != OPEN_DAY:
            for o in lst:
                if tdate(o) == d:
                    qty += o["quantity"] if o["side"] == "B" else -o["quantity"]
        recv = 0
        if d != OPEN_DAY:
            recv = sum(o["quantity"] for o in lst if o["side"] == "B" and tdate(o) in (d, prev_td(d)))
        assert qty >= 0
        if qty > 0:
            positions.append((d, a, s, qty, min(recv, qty), close_px[(s, d)]))

# ---------------- cash_txn ----------------
def money(x):
    return Decimal(x).quantize(Decimal("1"), rounding=ROUND_HALF_UP)

cash = []
events = []   # (date, ts, account, type, amount, ref)
for o in filled:
    d = tdate(o)
    val = money(o["quantity"] * o["price"])
    fee = money(val * Decimal("0.0015"))
    events.append((d, o["order_ts"].replace(hour=15, minute=30, second=0), o["account_id"], "FEE", fee, o["order_id"]))
    if o["side"] == "S":
        tax = money(val * Decimal("0.001"))
        events.append((d, o["order_ts"].replace(hour=15, minute=30, second=0), o["account_id"], "TAX_SELL", tax, o["order_id"]))
    sd = t_plus(d, 2)
    sts = dt.datetime(sd.year, sd.month, sd.day, 16, 0, 0, tzinfo=ICT)
    events.append((sd, sts, o["account_id"], "BUY_SETTLE" if o["side"] == "B" else "SELL_SETTLE", val, o["order_id"]))
# nạp, rút giữa kỳ
for a in active:
    for _ in range(R.randint(0, 3)):
        d = R.choice(DAYS)
        hh = R.choice([10, 14, 21])            # 21h: giao dịch ngoài giờ
        ts = dt.datetime(d.year, d.month, d.day, hh, R.randint(0, 59), 0, tzinfo=ICT)
        if R.random() < 0.55:
            events.append((d, ts, a, "DEPOSIT", money(R.choice([50, 100, 200, 500]) * 1_000_000), None))
        else:
            events.append((d, ts, a, "WITHDRAW", money(R.choice([20, 50, 100, 300]) * 1_000_000), None))
SIGN = {"DEPOSIT": 1, "SELL_SETTLE": 1, "WITHDRAW": -1, "BUY_SETTLE": -1, "FEE": -1, "TAX_SELL": -1}
# số dư đầu kỳ: nạp ngày 27/02 đủ để số dư không âm (tài khoản thường), cộng đệm
events.sort(key=lambda e: (e[1], e[3]))
need = defaultdict(Decimal)
run = defaultdict(Decimal)
for e in events:
    run[e[2]] += SIGN[e[3]] * e[4]
    need[e[2]] = min(need[e[2]], run[e[2]])
for a in [x["account_id"] for x in accounts]:
    if a in inactive and R.random() < 0.4:
        continue                                    # vài tài khoản không có giao dịch tiền nào
    base = -need[a] + money(R.choice([20, 50, 100, 300]) * 1_000_000)
    base = (base / 1_000_000).quantize(Decimal("1"), rounding="ROUND_CEILING") * 1_000_000
    events.append((OPEN_DAY, dt.datetime(2026, 2, 27, 10, 0, 0, tzinfo=ICT), a, "DEPOSIT", money(base), None))
# bẫy: tài khoản mồ côi
events.append((dt.date(2026, 3, 10), dt.datetime(2026, 3, 10, 10, 5, 0, tzinfo=ICT), "LTA099", "DEPOSIT", money(80_000_000), None))
events.append((dt.date(2026, 3, 18), dt.datetime(2026, 3, 18, 14, 40, 0, tzinfo=ICT), "LTA099", "WITHDRAW", money(30_000_000), None))
events.sort(key=lambda e: (e[1], e[2], e[3], e[5] or ""))
for i, e in enumerate(events, 1):
    cash.append((f"LTT{i:05d}", e[2], e[1], e[3], e[4], e[5]))

# ---------------- Ghi SQL ----------------
def q(v):
    if v is None:
        return "null"
    if isinstance(v, (int, Decimal)):
        return str(v)
    if isinstance(v, dt.datetime):
        return "'" + v.isoformat(sep=" ") + "'"
    if isinstance(v, dt.date):
        return "'" + v.isoformat() + "'"
    return "'" + str(v).replace("'", "''") + "'"

def inserts(f, table, cols, rows, chunk=500):
    for i in range(0, len(rows), chunk):
        f.write(f"insert into {SCHEMA}.{table} ({', '.join(cols)}) values\n")
        f.write(",\n".join("(" + ", ".join(q(v) for v in r) + ")" for r in rows[i:i + chunk]))
        f.write(";\n")

import os
OUT_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), OUT)   # ghi cạnh file script
with open(OUT_PATH, "w", encoding="utf-8") as f:
    f.write(f"""-- =============================================================================
-- Finova Onboarding · Tuần 3 · Dữ liệu raw (mô phỏng) · schema {SCHEMA}
-- 5 bảng giữ đúng cột của tuần 1 + 2 bảng mới: cash_txn, position_daily.
-- Chạy: psql -v ON_ERROR_STOP=1 -f {OUT}   (hoặc mở trong DBeaver, Execute Script)
-- Sinh bằng gen_w3_data.py, seed 20261005. Không phải dữ liệu khách hàng thật.
-- =============================================================================
drop schema if exists {SCHEMA} cascade;
create schema {SCHEMA};

create table {SCHEMA}.branches (
  branch_code  text primary key,
  branch_name  text not null,
  parent_code  text
);
create table {SCHEMA}.customers (            -- mỗi dòng là một phiên bản của khách hàng
  customer_id  text not null,
  segment      text not null,
  kyc_status   text not null,
  updated_at   date not null
);
create table {SCHEMA}.accounts (
  account_id   text primary key,
  customer_id  text not null,
  branch_code  text not null,
  account_type text not null,
  open_date    date not null
);
create table {SCHEMA}.instruments (
  symbol          text primary key,
  instrument_name text not null,
  exchange        text not null,
  sector          text not null,
  listing_date    date not null
);
create table {SCHEMA}.orders (
  order_id   text primary key,
  account_id text not null,
  symbol     text not null,
  side       char(1) not null,          -- B mua, S bán
  quantity   integer not null,
  price      numeric(18,2) not null,    -- đồng/cổ phiếu
  order_ts   timestamptz not null,
  status     text not null              -- Filled, Partial, Cancelled, Rejected
);
create table {SCHEMA}.cash_txn (         -- MỚI: giao dịch tiền; amount luôn dương, chiều theo txn_type
  txn_id       text primary key,
  account_id   text not null,
  txn_ts       timestamptz not null,
  txn_type     text not null,           -- DEPOSIT, WITHDRAW, BUY_SETTLE, SELL_SETTLE, FEE, TAX_SELL
  amount       numeric(20,2) not null,
  ref_order_id text                     -- lệnh gốc với FEE, TAX_SELL, *_SETTLE
);
create table {SCHEMA}.position_daily (   -- MỚI: số dư chứng khoán cuối ngày, chỉ có dòng khi total_qty > 0
  snapshot_date date not null,
  account_id    text not null,
  symbol        text not null,
  total_qty     integer not null,       -- tổng khối lượng sở hữu
  receiving_qty integer not null,       -- khối lượng mua đang chờ về
  close_price   numeric(18,2) not null, -- giá tham chiếu cuối ngày (mô phỏng)
  primary key (snapshot_date, account_id, symbol)
);
""")
    inserts(f, "branches", ["branch_code", "branch_name", "parent_code"], BRANCHES)
    inserts(f, "customers", ["customer_id", "segment", "kyc_status", "updated_at"], cust_all)
    inserts(f, "accounts", ["account_id", "customer_id", "branch_code", "account_type", "open_date"],
            [(a["account_id"], a["customer_id"], a["branch_code"], a["account_type"], a["open_date"]) for a in accounts])
    instr = []
    for s in ALL_SYMS:
        instr.append((s, f"CTCP mã {s} (mô phỏng)", "HOSE", SYM_SECTOR[s],
                      dt.date(2006, 1, 1) + dt.timedelta(days=R.randint(0, 5000))))
    inserts(f, "instruments", ["symbol", "instrument_name", "exchange", "sector", "listing_date"], instr)
    inserts(f, "orders", ["order_id", "account_id", "symbol", "side", "quantity", "price", "order_ts", "status"],
            [(o["order_id"], o["account_id"], o["symbol"], o["side"], o["quantity"], o["price"], o["order_ts"], o["status"]) for o in orders])
    inserts(f, "cash_txn", ["txn_id", "account_id", "txn_ts", "txn_type", "amount", "ref_order_id"], cash)
    inserts(f, "position_daily", ["snapshot_date", "account_id", "symbol", "total_qty", "receiving_qty", "close_price"], positions)
    f.write("analyze;\n")

print("customers", len(cust_all), "accounts", len(accounts), "orders", len(orders), "filled", len(filled),
      "cash", len(cash), "positions", len(positions))

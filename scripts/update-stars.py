#!/usr/bin/env python3
"""Record daily total Stars, without collecting stargazers' identities."""
import argparse
import csv
import json
import math
import os
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "docs/stars-history.csv"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--stars", type=int, help="Use an already verified GitHub API count")
    args = parser.parse_args()
    stars = args.stars
    if stars is None:
        headers = {"Accept": "application/vnd.github+json", "User-Agent": "logi-dashboard-lite-stars"}
        token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
        if token:
            headers["Authorization"] = f"Bearer {token}"
        request = Request("https://api.github.com/repos/tap6/logi-dashboard-lite", headers=headers)
        with urlopen(request, timeout=30) as response:
            stars = json.load(response)["stargazers_count"]
    if not isinstance(stars, int) or stars < 0:
        raise ValueError("Invalid Stars count")
    rows = {}
    if DATA.exists():
        with DATA.open(newline="") as source:
            rows = {row["date_utc"]: int(row["stars"]) for row in csv.DictReader(source)}
    rows[datetime.now(timezone.utc).date().isoformat()] = stars
    DATA.parent.mkdir(parents=True, exist_ok=True)
    with DATA.open("w", newline="") as target:
        writer = csv.writer(target, lineterminator="\n")
        writer.writerow(["date_utc", "stars"])
        writer.writerows(sorted(rows.items()))
    render(sorted(rows.items()))
    print(f"Recorded {stars} total Stars; {len(rows)} daily snapshot(s).")


def render(rows):
    width, height = 900, 320
    left, right, top, bottom = 66, 868, 82, 245
    ymax = max(5, math.ceil(max(value for _, value in rows) * 1.2 / 5) * 5)
    def point(index, value):
        x = (left + right) / 2 if len(rows) == 1 else left + (right - left) * index / (len(rows) - 1)
        y = bottom - (bottom - top) * value / ymax
        return x, y
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-labelledby="title description">',
           '<title id="title">Logi Dashboard Lite — Stars over time</title>',
           '<desc id="description">Daily total Stars from the GitHub repository API. Observations start when this project is published.</desc>',
           '<style>text{font-family:system-ui,sans-serif;fill:#334155}.small{font-size:12px}.grid{stroke:#e2e8f0}.card{fill:#f8fafc}@media(prefers-color-scheme:dark){text{fill:#cbd5e1}.grid{stroke:#334155}.card{fill:#0f172a}}</style>',
           '<rect class="card" width="900" height="320" rx="16"/>',
           '<text x="28" y="36" font-size="19" font-weight="600">Stars over time</text>',
           f'<text class="small" x="28" y="58">tap6/logi-dashboard-lite · {rows[-1][1]} Stars · daily snapshots (UTC)</text>']
    for step in range(6):
        value = ymax * step / 5
        y = bottom - (bottom - top) * step / 5
        svg += [f'<line class="grid" x1="{left}" y1="{y}" x2="{right}" y2="{y}"/>',
                f'<text class="small" x="52" y="{y+4}" text-anchor="end">{int(value)}</text>']
    coords = [point(i, value) for i, (_, value) in enumerate(rows)]
    if len(coords) > 1:
        points = " ".join(f"{x:.1f},{y:.1f}" for x, y in coords)
        svg.append(f'<polyline points="{points}" fill="none" stroke="#10b981" stroke-width="3" stroke-linejoin="round"/>')
    for index in sorted({0, len(rows) - 1}):
        x, y = coords[index]
        svg += [f'<circle cx="{x:.1f}" cy="{y:.1f}" r="5" fill="#10b981"/>',
                f'<text class="small" x="{x:.1f}" y="268" text-anchor="middle">{rows[index][0]}</text>']
    svg += [f'<text class="small" x="28" y="299">Recording started {rows[0][0]}. Historical values are not backfilled.</text>', '</svg>']
    (ROOT / "docs/stars-history.svg").write_text("\n".join(svg) + "\n")
    table = "# Stars history / Stars 时间表\n\nDaily total Stars snapshots (UTC), not individual stargazer records.\n\n| Date (UTC) | Stars |\n| --- | ---: |\n"
    table += "".join(f"| {date} | {value} |\n" for date, value in rows)
    (ROOT / "docs/stars-history.md").write_text(table)


if __name__ == "__main__":
    main()

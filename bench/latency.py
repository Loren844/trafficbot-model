"""Mesure de la latence d'inférence seule d'un modèle ONNX avec ONNX Runtime.

Latence mesurée : de l'appel à session.run() (tenseur d'entrée prêt)
jusqu'au retour des sorties. Capture, prétraitement et post-traitement
ne sont pas inclus.

Exemple :
    python bench/latency.py --model yolov8n.onnx --machine mac
"""

import argparse
import csv
import datetime
import os
import platform
import time

import numpy as np
import onnxruntime as ort


def parse_args():
    p = argparse.ArgumentParser(description="Latence d'inférence ONNX Runtime")
    p.add_argument("--model", required=True, help="chemin du fichier .onnx")
    p.add_argument("--machine", required=True, help="nom de la machine (mac, pc, pi4, pi5)")
    p.add_argument("--imgsz", type=int, default=320, help="taille d'entrée en pixels")
    p.add_argument("--warmup", type=int, default=20, help="inférences de chauffe non comptées")
    p.add_argument("--runs", type=int, default=500, help="inférences mesurées")
    p.add_argument("--threads", type=int, default=0, help="threads intra-op (0 = défaut ORT)")
    p.add_argument("--seed", type=int, default=0, help="graine de l'entrée aléatoire")
    p.add_argument("--out", default="results", help="dossier de sortie des CSV")
    return p.parse_args()


def make_session(model, threads):
    opts = ort.SessionOptions()
    if threads > 0:
        opts.intra_op_num_threads = threads
    return ort.InferenceSession(model, sess_options=opts, providers=["CPUExecutionProvider"])


def main():
    args = parse_args()

    t0 = time.perf_counter()
    session = make_session(args.model, args.threads)
    load_s = time.perf_counter() - t0

    inp = session.get_inputs()[0]
    rng = np.random.default_rng(args.seed)
    x = rng.random((1, 3, args.imgsz, args.imgsz), dtype=np.float32)
    feed = {inp.name: x}

    for _ in range(args.warmup):
        session.run(None, feed)

    lat_ms = np.empty(args.runs)
    for i in range(args.runs):
        t = time.perf_counter()
        session.run(None, feed)
        lat_ms[i] = (time.perf_counter() - t) * 1000.0

    p50, p95, p99 = np.percentile(lat_ms, [50, 95, 99])

    meta = {
        "date": datetime.datetime.now().isoformat(timespec="seconds"),
        "machine": args.machine,
        "cpu": platform.processor() or platform.machine(),
        "os": platform.platform(),
        "python": platform.python_version(),
        "runtime": "onnxruntime",
        "runtime_version": ort.__version__,
        "provider": session.get_providers()[0],
        "model": os.path.basename(args.model),
        "imgsz": args.imgsz,
        "precision": inp.type,
        "threads": args.threads or "default",
        "warmup": args.warmup,
        "runs": args.runs,
        "load_s": round(load_s, 4),
    }

    os.makedirs(args.out, exist_ok=True)
    stem = f"latency_{args.machine}_{os.path.splitext(meta['model'])[0]}_{args.imgsz}"

    with open(os.path.join(args.out, stem + "_runs.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(list(meta) + ["run", "latency_ms"])
        for i, v in enumerate(lat_ms):
            w.writerow(list(meta.values()) + [i, round(v, 4)])

    summary = dict(meta, p50_ms=round(p50, 3), p95_ms=round(p95, 3), p99_ms=round(p99, 3),
                   mean_ms=round(lat_ms.mean(), 3), std_ms=round(lat_ms.std(), 3))
    path = os.path.join(args.out, "latency_summary.csv")
    new = not os.path.exists(path)
    with open(path, "a", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(summary))
        if new:
            w.writeheader()
        w.writerow(summary)

    print(f"{meta['model']} {args.imgsz}px sur {args.machine} ({meta['provider']}) : "
          f"p50 {p50:.2f} ms, p95 {p95:.2f} ms, p99 {p99:.2f} ms, chargement {load_s:.2f} s")


if __name__ == "__main__":
    main()

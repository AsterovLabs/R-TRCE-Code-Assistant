"""
samples/06_python_pipeline.py -- Polyglot Data Pipeline Sample
Demonstrates data aggregation, summary metrics, and component architecture in Python.
"""

import math
import sys

def calculate_summary(scores):
    """Computes descriptive statistics for a sequence of numeric scores."""
    if not scores:
        return {"count": 0, "mean": 0.0, "std": 0.0}
    
    n = len(scores)
    mean_val = sum(scores) / n
    variance = sum((x - mean_val) ** 2 for x in scores) / (n - 1 if n > 1 else 1)
    std_val = math.sqrt(variance)
    
    return {
        "count": n,
        "mean": round(mean_val, 2),
        "std": round(std_val, 2),
        "min": min(scores),
        "max": max(scores)
    }

class MetricPipeline:
    """Manages multi-stage metric calculations for batch records."""

    def __init__(self, name="DefaultPipeline"):
        self.name = name
        self.history = []

    def record(self, batch_id, values):
        summary = calculate_summary(values)
        entry = {"batch_id": batch_id, "summary": summary}
        self.history.append(entry)
        return summary

    def get_total_records(self):
        return sum(item["summary"]["count"] for item in self.history)


# Pipeline Demonstration Run
if __name__ == "__main__":
    pipeline = MetricPipeline("StudentScoreTracker")
    batch_a = [85, 92, 78, 90, 88, 76, 95]
    summary_a = pipeline.record("batch_01", batch_a)
    
    print(f"[{pipeline.name}] Batch 1 Summary:")
    for k, v in summary_a.items():
        print(f"  {k}: {v}")
    
    print(f"Total records processed: {pipeline.get_total_records()}")

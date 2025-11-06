"""
Enhanced Research Data Analysis Script for Azure Micro-Segmentation Study

Analyzes multi-sample attack simulation and performance test results with full statistical rigor:
- Confidence intervals (95% CI)
- Effect size analysis (Cohen's d)
- Statistical power calculations
- Multi-iteration data aggregation

Usage: python analyze-results-enhanced.py
Output: ./analysis-output/ directory with 10 charts and 4 CSV files
"""

import json
import os
from pathlib import Path
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats
from statsmodels.stats.power import TTestIndPower
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')

# Set publication-quality defaults
plt.rcParams['figure.dpi'] = 300
plt.rcParams['savefig.dpi'] = 300
plt.rcParams['font.size'] = 10
plt.rcParams['font.family'] = 'serif'
plt.rcParams['figure.figsize'] = (10, 6)

OUTPUT_DIR = Path("./analysis-output")
OUTPUT_DIR.mkdir(exist_ok=True)

print("=" * 70)
print("Enhanced Statistical Analysis - Azure Micro-Segmentation Research")
print("=" * 70)
print()


# ============================================================================
# STATISTICAL ANALYSIS FUNCTIONS
# ============================================================================

def calculate_confidence_interval(data, confidence=0.95):
    """
    Calculates confidence interval using t-distribution.

    Args:
        data: Array of numeric values
        confidence: Confidence level (default 0.95)

    Returns:
        Dict with mean, lower, upper, margin, std, n
    """
    data = np.array(data)
    data = data[~np.isnan(data)]

    if len(data) == 0:
        return {'mean': np.nan, 'lower': np.nan, 'upper': np.nan, 'margin': np.nan, 'std': np.nan, 'n': 0}

    if len(data) == 1:
        return {'mean': data[0], 'lower': np.nan, 'upper': np.nan, 'margin': np.nan, 'std': 0, 'n': 1}

    mean = np.mean(data)
    std = np.std(data, ddof=1)
    n = len(data)

    t_value = stats.t.ppf((1 + confidence) / 2, n - 1)
    margin = t_value * (std / np.sqrt(n))

    return {
        'mean': mean,
        'lower': mean - margin,
        'upper': mean + margin,
        'margin': margin,
        'std': std,
        'n': n
    }


def calculate_cohens_d(group1, group2):
    """
    Calculates Cohen's d effect size.

    Args:
        group1: Array of values for group 1
        group2: Array of values for group 2

    Returns:
        Cohen's d value
    """
    group1 = np.array(group1)
    group2 = np.array(group2)

    group1 = group1[~np.isnan(group1)]
    group2 = group2[~np.isnan(group2)]

    if len(group1) < 2 or len(group2) < 2:
        return np.nan

    mean1 = np.mean(group1)
    mean2 = np.mean(group2)
    std1 = np.std(group1, ddof=1)
    std2 = np.std(group2, ddof=1)
    n1 = len(group1)
    n2 = len(group2)

    pooled_std = np.sqrt(((n1 - 1) * std1**2 + (n2 - 1) * std2**2) / (n1 + n2 - 2))

    if pooled_std == 0:
        return np.nan

    return (mean1 - mean2) / pooled_std


def interpret_effect_size(d):
    """Interprets Cohen's d value."""
    if np.isnan(d):
        return "Undefined"
    abs_d = abs(d)
    if abs_d < 0.2:
        return "Negligible"
    elif abs_d < 0.5:
        return "Small"
    elif abs_d < 0.8:
        return "Medium"
    else:
        return "Large"


def calculate_performance_overhead(baseline_value, config_value, metric_type='latency'):
    """
    Calculates performance overhead relative to baseline.

    Args:
        baseline_value: Baseline performance value
        config_value: Configuration performance value
        metric_type: 'latency' (higher is worse) or 'throughput' (lower is worse)

    Returns:
        Overhead percentage
    """
    if np.isnan(baseline_value) or np.isnan(config_value) or baseline_value == 0:
        return np.nan

    # If config value is 0 or extremely small, it indicates missing/failed data
    if config_value == 0 or (metric_type == 'throughput' and config_value < 1):
        return np.nan

    if metric_type == 'latency':
        # For latency, increase is bad
        overhead = ((config_value - baseline_value) / baseline_value) * 100
    elif metric_type == 'throughput':
        # For throughput, decrease is bad
        overhead = ((baseline_value - config_value) / baseline_value) * 100
    else:
        overhead = ((config_value - baseline_value) / baseline_value) * 100

    return overhead


def calculate_statistical_power(effect_size, n, alpha=0.05):
    """
    Calculates statistical power for two-sample t-test.

    Args:
        effect_size: Cohen's d
        n: Sample size per group
        alpha: Significance level

    Returns:
        Power value (0-1)
    """
    if np.isnan(effect_size) or n < 2:
        return np.nan

    try:
        power_analysis = TTestIndPower()
        power = power_analysis.solve_power(
            effect_size=abs(effect_size),
            nobs1=n,
            alpha=alpha,
            alternative='two-sided'
        )
        return power
    except:
        return np.nan


def interpret_power(power):
    """Interprets statistical power value."""
    if np.isnan(power):
        return "Undefined"
    if power < 0.50:
        return "Low"
    elif power < 0.80:
        return "Moderate"
    elif power < 0.95:
        return "High"
    else:
        return "Excellent"


def validate_sample_size(n, config_name):
    """Validates and warns about sample size."""
    if n < 3:
        print(f"  WARNING: {config_name} has n={n}. Need n≥3 for valid statistics.")
        return False
    elif n < 5:
        print(f"  NOTE: {config_name} has n={n}. Recommend n≥5 for robust results.")
        return True
    return True


# ============================================================================
# MULTI-SAMPLE DATA LOADING
# ============================================================================

def find_config_files(base_dirs, config_name, file_type):
    """
    Finds all iteration files for a configuration.

    Args:
        base_dirs: List of directories to search
        config_name: Config name (e.g., 'baseline')
        file_type: 'attack' or 'performance' or 'summary'

    Returns:
        List of file paths
    """
    patterns = {
        'attack': f"attack-results-{config_name}-run*-*.json",
        'performance': f"performance-{config_name}-run*-*.json",
        'summary': f"summary-{config_name}-run*-*.json"
    }

    pattern = patterns.get(file_type, f"*{config_name}-run*-*.json")

    files = []
    for base_dir in base_dirs:
        base_path = Path(base_dir)
        if base_path.exists():
            found = list(base_path.glob(f"**/{pattern}"))
            files.extend(found)

    return sorted(files)


def load_attack_iterations(config_name):
    """
    Loads all attack result iterations for a configuration.

    Returns:
        List of dicts with metrics from each iteration
    """
    search_locations = [
        "./AttackResults",
        "./ResearchData",
        "C:/AttackResults",
        "C:/ResearchData"
    ]

    files = find_config_files(search_locations, config_name, 'attack')

    iterations = []
    for file_path in files:
        try:
            with open(file_path, 'r', encoding='utf-8-sig') as f:
                data = json.load(f)

            metrics = data.get('Metrics', {})
            iterations.append({
                'overall_success_rate': metrics.get('LateralMovementSuccessRate', 0),
                'rdp_success_rate': metrics.get('RDPSuccessRate', 0),
                'smb_success_rate': metrics.get('SMBSuccessRate', 0),
                'total_attempts': metrics.get('TotalLateralMovementAttempts', 0),
                'successful_movements': metrics.get('SuccessfulLateralMovements', 0)
            })
        except Exception as e:
            print(f"    Error reading {file_path.name}: {e}")
            continue

    return iterations


def load_performance_iterations(config_name):
    """
    Loads all performance test iterations for a configuration.

    Returns:
        List of dicts with metrics from each iteration
    """
    search_locations = [
        "./PerformanceResults",
        "./ResearchData",
        "C:/PerformanceResults",
        "C:/ResearchData"
    ]

    files = find_config_files(search_locations, config_name, 'performance')

    iterations = []
    for file_path in files:
        try:
            with open(file_path, 'r', encoding='utf-8-sig') as f:
                data = json.load(f)

            tests = data.get('Tests', {})

            latency_data = tests.get('Latency', [])
            avg_latencies = [item.get('AvgLatency', 0) for item in latency_data if item.get('AvgLatency')]
            p95_latencies = [item.get('P95Latency', 0) for item in latency_data if item.get('P95Latency')]
            p99_latencies = [item.get('P99Latency', 0) for item in latency_data if item.get('P99Latency')]

            throughput_data = tests.get('Throughput', [])
            throughputs = [item.get('ThroughputMbps', 0) for item in throughput_data
                          if item.get('Success') and item.get('ThroughputMbps')]

            auth_data = tests.get('Authentication', [])
            auth_times = [item.get('AvgAuthTime', 0) for item in auth_data
                         if item.get('Success') and item.get('AvgAuthTime')]

            resource_data = tests.get('ResourceUtilization', {})
            cpu_usage = resource_data.get('CPU', {}).get('AveragePercent', 0)
            memory_usage = resource_data.get('Memory', {}).get('UsedPercent', 0)

            iterations.append({
                'latency_avg': np.mean(avg_latencies) if avg_latencies else 0,
                'latency_p95': np.mean(p95_latencies) if p95_latencies else 0,
                'latency_p99': np.mean(p99_latencies) if p99_latencies else 0,
                'throughput': np.mean(throughputs) if throughputs else 0,
                'auth_overhead': np.mean(auth_times) if auth_times else 0,
                'cpu_usage': cpu_usage,
                'memory_usage': memory_usage
            })
        except Exception as e:
            print(f"    Error reading {file_path.name}: {e}")
            continue

    return iterations


def aggregate_config_data(config_name):
    """
    Loads all iterations and calculates aggregated statistics.

    Returns:
        Dict with iterations and aggregated stats with CI
    """
    print(f"  Loading {config_name}...")

    attack_iters = load_attack_iterations(config_name)
    perf_iters = load_performance_iterations(config_name)

    n_attack = len(attack_iters)
    n_perf = len(perf_iters)
    n = min(n_attack, n_perf) if n_attack > 0 and n_perf > 0 else max(n_attack, n_perf)

    if n == 0:
        print(f"    No data found for {config_name}")
        return None

    print(f"    Found {n_attack} attack iterations, {n_perf} performance iterations")
    validate_sample_size(n, config_name)

    # Aggregate attack metrics
    attack_metrics = {}
    if attack_iters:
        for key in attack_iters[0].keys():
            values = [it[key] for it in attack_iters]
            attack_metrics[key] = calculate_confidence_interval(values)

    # Aggregate performance metrics
    perf_metrics = {}
    if perf_iters:
        for key in perf_iters[0].keys():
            values = [it[key] for it in perf_iters]
            perf_metrics[key] = calculate_confidence_interval(values)

    return {
        'config': config_name,
        'n': n,
        'attack_iterations': attack_iters,
        'perf_iterations': perf_iters,
        'attack_metrics': attack_metrics,
        'perf_metrics': perf_metrics
    }


def load_all_configurations():
    """
    Loads data for all configurations.

    Returns:
        Dict mapping config names to aggregated data
    """
    print("\n[1] Loading Multi-Sample Data")
    print("-" * 70)

    configs = ['baseline', 'config1', 'config2', 'config3']
    all_data = {}

    for config in configs:
        data = aggregate_config_data(config)
        if data:
            all_data[config] = data

    if not all_data:
        print("\nNo data found. Check file locations:")
        print("  - ./AttackResults/ or C:/AttackResults/")
        print("  - ./PerformanceResults/ or C:/PerformanceResults/")
        print("  - ./ResearchData/ or C:/ResearchData/")
        return None

    print(f"\nLoaded {len(all_data)} configurations")
    return all_data


# ============================================================================
# VISUALIZATION WITH ERROR BARS
# ============================================================================

def create_lateral_movement_chart_with_ci(all_data):
    """Creates bar chart with 95% CI error bars."""
    print("\n[2] Generating lateral movement success rate chart with CI")

    if not all_data:
        print("  No data to plot")
        return

    configs = []
    means = []
    errors = []

    config_order = ['baseline', 'config1', 'config2', 'config3']
    for config in config_order:
        if config in all_data:
            metric = all_data[config]['attack_metrics'].get('overall_success_rate', {})
            configs.append(config)
            means.append(metric.get('mean', 0))
            errors.append(metric.get('margin', 0))

    fig, ax = plt.subplots(figsize=(10, 6))

    colors = ['#d62728', '#ff7f0e', '#2ca02c', '#1f77b4']
    x = range(len(configs))

    bars = ax.bar(x, means, color=colors[:len(configs)], alpha=0.8, edgecolor='black')
    ax.errorbar(x, means, yerr=errors, fmt='none', color='black', capsize=5, linewidth=2)

    for i, (bar, mean, err) in enumerate(zip(bars, means, errors)):
        height = bar.get_height()
        if not np.isnan(err):
            ax.text(bar.get_x() + bar.get_width()/2., height + err + 2,
                    f'{mean:.1f}%\n±{err:.1f}',
                    ha='center', va='bottom', fontweight='bold', fontsize=9)
        else:
            ax.text(bar.get_x() + bar.get_width()/2., height + 2,
                    f'{mean:.1f}%',
                    ha='center', va='bottom', fontweight='bold', fontsize=9)

    ax.set_xlabel('Configuration', fontsize=12, fontweight='bold')
    ax.set_ylabel('Lateral Movement Success Rate (%)', fontsize=12, fontweight='bold')
    ax.set_title('Lateral Movement Success Rate by Configuration (with 95% CI)',
                 fontsize=14, fontweight='bold', pad=20)
    ax.set_xticks(x)

    config_labels = {
        'baseline': 'Baseline\n(Flat Network)',
        'config1': 'Config 1\n(NSG Segmentation)',
        'config2': 'Config 2\n(ASG Segmentation)',
        'config3': 'Config 3\n(Firewall + NSG + ASG)'
    }
    ax.set_xticklabels([config_labels.get(c, c) for c in configs], fontsize=10)
    ax.set_ylim(0, 110)
    ax.grid(axis='y', alpha=0.3, linestyle='--')

    plt.tight_layout()
    output_file = OUTPUT_DIR / "1_lateral_movement_success_rates.png"
    plt.savefig(output_file, bbox_inches='tight')
    print(f"  Saved: {output_file.name}")
    plt.close()


def create_attack_breakdown_chart_with_ci(all_data):
    """Creates grouped bar chart with error bars for RDP vs SMB."""
    print("\n[3] Generating attack method breakdown chart with CI")

    if not all_data:
        print("  No data to plot")
        return

    config_order = ['baseline', 'config1', 'config2', 'config3']
    configs = [c for c in config_order if c in all_data]

    rdp_means = []
    rdp_errors = []
    smb_means = []
    smb_errors = []

    for config in configs:
        rdp_metric = all_data[config]['attack_metrics'].get('rdp_success_rate', {})
        smb_metric = all_data[config]['attack_metrics'].get('smb_success_rate', {})

        rdp_means.append(rdp_metric.get('mean', 0))
        rdp_errors.append(rdp_metric.get('margin', 0))
        smb_means.append(smb_metric.get('mean', 0))
        smb_errors.append(smb_metric.get('margin', 0))

    fig, ax = plt.subplots(figsize=(12, 6))

    x = np.arange(len(configs))
    width = 0.35

    bars1 = ax.bar(x - width/2, rdp_means, width, label='RDP',
                   color='#e74c3c', alpha=0.8, edgecolor='black')
    bars2 = ax.bar(x + width/2, smb_means, width, label='SMB',
                   color='#3498db', alpha=0.8, edgecolor='black')

    ax.errorbar(x - width/2, rdp_means, yerr=rdp_errors, fmt='none', color='black', capsize=4)
    ax.errorbar(x + width/2, smb_means, yerr=smb_errors, fmt='none', color='black', capsize=4)

    for bars in [bars1, bars2]:
        for bar in bars:
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height,
                    f'{height:.0f}%',
                    ha='center', va='bottom', fontsize=9)

    ax.set_xlabel('Configuration', fontsize=12, fontweight='bold')
    ax.set_ylabel('Success Rate (%)', fontsize=12, fontweight='bold')
    ax.set_title('Lateral Movement Success Rate by Attack Method (with 95% CI)',
                 fontsize=14, fontweight='bold', pad=20)
    ax.set_xticks(x)
    config_labels = {
        'baseline': 'Baseline',
        'config1': 'Config 1\n(NSG)',
        'config2': 'Config 2\n(ASG)',
        'config3': 'Config 3\n(Firewall)'
    }
    ax.set_xticklabels([config_labels.get(c, c) for c in configs], fontsize=10)
    ax.set_ylim(0, 110)
    ax.legend(fontsize=11, loc='upper right')
    ax.grid(axis='y', alpha=0.3, linestyle='--')

    plt.tight_layout()
    output_file = OUTPUT_DIR / "2_attack_method_breakdown.png"
    plt.savefig(output_file, bbox_inches='tight')
    print(f"  Saved: {output_file.name}")
    plt.close()


def create_latency_chart_with_ci(all_data):
    """Creates latency comparison chart with error bars."""
    print("\n[4] Generating network latency comparison chart with CI")

    if not all_data:
        print("  No data to plot")
        return

    config_order = ['baseline', 'config1', 'config2', 'config3']
    configs = [c for c in config_order if c in all_data]

    avg_means = []
    avg_errors = []
    p95_means = []
    p99_means = []

    for config in configs:
        avg_metric = all_data[config]['perf_metrics'].get('latency_avg', {})
        p95_metric = all_data[config]['perf_metrics'].get('latency_p95', {})
        p99_metric = all_data[config]['perf_metrics'].get('latency_p99', {})

        avg_means.append(avg_metric.get('mean', 0))
        avg_errors.append(avg_metric.get('margin', 0))
        p95_means.append(p95_metric.get('mean', 0))
        p99_means.append(p99_metric.get('mean', 0))

    fig, ax = plt.subplots(figsize=(12, 6))

    x = np.arange(len(configs))
    width = 0.25

    bars1 = ax.bar(x - width, avg_means, width, label='Average',
                   color='#2ecc71', alpha=0.8, edgecolor='black')
    bars2 = ax.bar(x, p95_means, width, label='P95',
                   color='#f39c12', alpha=0.8, edgecolor='black')
    bars3 = ax.bar(x + width, p99_means, width, label='P99',
                   color='#e74c3c', alpha=0.8, edgecolor='black')

    ax.errorbar(x - width, avg_means, yerr=avg_errors, fmt='none', color='black', capsize=4)

    for bars in [bars1, bars2, bars3]:
        for bar in bars:
            height = bar.get_height()
            if height > 0:
                ax.text(bar.get_x() + bar.get_width()/2., height,
                        f'{height:.1f}',
                        ha='center', va='bottom', fontsize=8)

    ax.set_xlabel('Configuration', fontsize=12, fontweight='bold')
    ax.set_ylabel('Latency (milliseconds)', fontsize=12, fontweight='bold')
    ax.set_title('Network Latency Comparison (with 95% CI on Average)',
                 fontsize=14, fontweight='bold', pad=20)
    ax.set_xticks(x)
    config_labels = {
        'baseline': 'Baseline',
        'config1': 'Config 1\n(NSG)',
        'config2': 'Config 2\n(ASG)',
        'config3': 'Config 3\n(Firewall)'
    }
    ax.set_xticklabels([config_labels.get(c, c) for c in configs], fontsize=10)
    ax.legend(fontsize=11, loc='upper left')
    ax.grid(axis='y', alpha=0.3, linestyle='--')

    plt.tight_layout()
    output_file = OUTPUT_DIR / "3_network_latency_comparison.png"
    plt.savefig(output_file, bbox_inches='tight')
    print(f"  Saved: {output_file.name}")
    plt.close()


def create_throughput_chart_with_ci(all_data):
    """Creates throughput chart with error bars."""
    print("\n[5] Generating network throughput chart with CI")

    if not all_data:
        print("  No data to plot")
        return

    config_order = ['baseline', 'config1', 'config2', 'config3']
    configs = [c for c in config_order if c in all_data]

    means = []
    errors = []

    for config in configs:
        metric = all_data[config]['perf_metrics'].get('throughput', {})
        means.append(metric.get('mean', 0))
        errors.append(metric.get('margin', 0))

    fig, ax = plt.subplots(figsize=(10, 6))

    colors = ['#3498db', '#9b59b6', '#1abc9c', '#e67e22']
    x = range(len(configs))

    bars = ax.bar(x, means, color=colors[:len(configs)], alpha=0.8, edgecolor='black')
    ax.errorbar(x, means, yerr=errors, fmt='none', color='black', capsize=5, linewidth=2)

    for bar, mean, err in zip(bars, means, errors):
        height = bar.get_height()
        if not np.isnan(err) and height > 0:
            ax.text(bar.get_x() + bar.get_width()/2., height + err + 2,
                    f'{mean:.1f}\n±{err:.1f}',
                    ha='center', va='bottom', fontweight='bold', fontsize=10)
        elif height > 0:
            ax.text(bar.get_x() + bar.get_width()/2., height + 2,
                    f'{mean:.1f}',
                    ha='center', va='bottom', fontweight='bold', fontsize=10)

    ax.set_xlabel('Configuration', fontsize=12, fontweight='bold')
    ax.set_ylabel('Throughput (Mbps)', fontsize=12, fontweight='bold')
    ax.set_title('Network Throughput Comparison (with 95% CI)', fontsize=14, fontweight='bold', pad=20)
    ax.set_xticks(x)
    config_labels = {
        'baseline': 'Baseline',
        'config1': 'Config 1\n(NSG)',
        'config2': 'Config 2\n(ASG)',
        'config3': 'Config 3\n(Firewall)'
    }
    ax.set_xticklabels([config_labels.get(c, c) for c in configs], fontsize=10)
    ax.grid(axis='y', alpha=0.3, linestyle='--')

    plt.tight_layout()
    output_file = OUTPUT_DIR / "4_network_throughput.png"
    plt.savefig(output_file, bbox_inches='tight')
    print(f"  Saved: {output_file.name}")
    plt.close()


def create_resource_utilization_chart_with_ci(all_data):
    """Creates resource utilization chart with error bars."""
    print("\n[6] Generating resource utilization chart with CI")

    if not all_data:
        print("  No data to plot")
        return

    config_order = ['baseline', 'config1', 'config2', 'config3']
    configs = [c for c in config_order if c in all_data]

    cpu_means = []
    cpu_errors = []
    mem_means = []
    mem_errors = []

    for config in configs:
        cpu_metric = all_data[config]['perf_metrics'].get('cpu_usage', {})
        mem_metric = all_data[config]['perf_metrics'].get('memory_usage', {})

        cpu_means.append(cpu_metric.get('mean', 0))
        cpu_errors.append(cpu_metric.get('margin', 0))
        mem_means.append(mem_metric.get('mean', 0))
        mem_errors.append(mem_metric.get('margin', 0))

    fig, ax = plt.subplots(figsize=(10, 6))

    x = np.arange(len(configs))
    width = 0.35

    bars1 = ax.bar(x - width/2, cpu_means, width, label='CPU Usage',
                   color='#e74c3c', alpha=0.8, edgecolor='black')
    bars2 = ax.bar(x + width/2, mem_means, width, label='Memory Usage',
                   color='#3498db', alpha=0.8, edgecolor='black')

    ax.errorbar(x - width/2, cpu_means, yerr=cpu_errors, fmt='none', color='black', capsize=4)
    ax.errorbar(x + width/2, mem_means, yerr=mem_errors, fmt='none', color='black', capsize=4)

    for bars in [bars1, bars2]:
        for bar in bars:
            height = bar.get_height()
            if height > 0:
                ax.text(bar.get_x() + bar.get_width()/2., height,
                        f'{height:.1f}%',
                        ha='center', va='bottom', fontsize=9)

    ax.set_xlabel('Configuration', fontsize=12, fontweight='bold')
    ax.set_ylabel('Utilization (%)', fontsize=12, fontweight='bold')
    ax.set_title('Resource Utilization Comparison (with 95% CI)', fontsize=14, fontweight='bold', pad=20)
    ax.set_xticks(x)
    config_labels = {
        'baseline': 'Baseline',
        'config1': 'Config 1\n(NSG)',
        'config2': 'Config 2\n(ASG)',
        'config3': 'Config 3\n(Firewall)'
    }
    ax.set_xticklabels([config_labels.get(c, c) for c in configs], fontsize=10)
    ax.set_ylim(0, 100)
    ax.legend(fontsize=11, loc='upper right')
    ax.grid(axis='y', alpha=0.3, linestyle='--')

    plt.tight_layout()
    output_file = OUTPUT_DIR / "5_resource_utilization.png"
    plt.savefig(output_file, bbox_inches='tight')
    print(f"  Saved: {output_file.name}")
    plt.close()


def create_heatmap(all_data):
    """Creates attack success heatmap."""
    print("\n[7] Generating attack success heatmap")

    if not all_data:
        print("  No data to plot")
        return

    config_order = ['baseline', 'config1', 'config2', 'config3']
    configs = [c for c in config_order if c in all_data]

    rdp_values = []
    smb_values = []

    for config in configs:
        rdp_metric = all_data[config]['attack_metrics'].get('rdp_success_rate', {})
        smb_metric = all_data[config]['attack_metrics'].get('smb_success_rate', {})
        rdp_values.append(rdp_metric.get('mean', 0))
        smb_values.append(smb_metric.get('mean', 0))

    heatmap_data = pd.DataFrame({
        'RDP': rdp_values,
        'SMB': smb_values
    })

    config_label_map = {
        'baseline': 'Baseline',
        'config1': 'Config 1 (NSG)',
        'config2': 'Config 2 (ASG)',
        'config3': 'Config 3 (Firewall)'
    }
    heatmap_data.index = [config_label_map.get(c, c) for c in configs]

    fig, ax = plt.subplots(figsize=(8, 6))

    sns.heatmap(heatmap_data, annot=True, fmt='.1f', cmap='RdYlGn_r',
                linewidths=2, linecolor='black', cbar_kws={'label': 'Success Rate (%)'},
                vmin=0, vmax=100, ax=ax)

    ax.set_title('Attack Success Rate Heatmap', fontsize=14, fontweight='bold', pad=20)
    ax.set_xlabel('Attack Method', fontsize=12, fontweight='bold')
    ax.set_ylabel('Configuration', fontsize=12, fontweight='bold')

    plt.tight_layout()
    output_file = OUTPUT_DIR / "6_attack_success_heatmap.png"
    plt.savefig(output_file, bbox_inches='tight')
    print(f"  Saved: {output_file.name}")
    plt.close()


# ============================================================================
# ENHANCED STATISTICAL OUTPUTS
# ============================================================================

def create_enhanced_comparison_table(all_data):
    """Creates detailed comparison table with CI, deltas, and effect sizes."""
    print("\n[8] Generating enhanced comparison table with statistics")

    if not all_data:
        print("  No data to create table")
        return

    config_order = ['baseline', 'config1', 'config2', 'config3']
    configs = [c for c in config_order if c in all_data]

    if 'baseline' not in all_data:
        print("  Warning: No baseline data for comparison")
        return

    baseline = all_data['baseline']

    rows = []
    for config in configs:
        data = all_data[config]

        success_metric = data['attack_metrics'].get('overall_success_rate', {})
        latency_metric = data['perf_metrics'].get('latency_avg', {})
        cpu_metric = data['perf_metrics'].get('cpu_usage', {})
        mem_metric = data['perf_metrics'].get('memory_usage', {})

        success_mean = success_metric.get('mean', 0)
        success_ci = success_metric.get('margin', 0)
        latency_mean = latency_metric.get('mean', 0)
        latency_ci = latency_metric.get('margin', 0)
        cpu_mean = cpu_metric.get('mean', 0)
        mem_mean = mem_metric.get('mean', 0)

        if config != 'baseline':
            baseline_success = baseline['attack_metrics']['overall_success_rate']['mean']
            baseline_latency = baseline['perf_metrics']['latency_avg']['mean']
            baseline_cpu = baseline['perf_metrics']['cpu_usage']['mean']

            delta_success = success_mean - baseline_success
            delta_success_pct = (delta_success / baseline_success * 100) if baseline_success != 0 else 0
            delta_latency = latency_mean - baseline_latency
            delta_latency_pct = (delta_latency / baseline_latency * 100) if baseline_latency != 0 else 0
            delta_cpu = cpu_mean - baseline_cpu

            success_iters = [it['overall_success_rate'] for it in data['attack_iterations']]
            baseline_success_iters = [it['overall_success_rate'] for it in baseline['attack_iterations']]
            cohens_d = calculate_cohens_d(baseline_success_iters, success_iters)
            effect = interpret_effect_size(cohens_d)
            power = calculate_statistical_power(cohens_d, data['n'])
            power_interp = interpret_power(power)
        else:
            delta_success = 0
            delta_success_pct = 0
            delta_latency = 0
            delta_latency_pct = 0
            delta_cpu = 0
            cohens_d = 0
            effect = "Baseline"
            power = 1.0
            power_interp = "Baseline"

        row = {
            'Configuration': config,
            'n': data['n'],
            'Success_Rate': f"{success_mean:.1f}±{success_ci:.1f}%",
            'Δ_Success_vs_Baseline': f"{delta_success:+.1f}%",
            'Δ_Success_Pct': f"{delta_success_pct:+.1f}%",
            'Cohens_d': f"{cohens_d:.3f}" if not np.isnan(cohens_d) else "N/A",
            'Effect_Size': effect,
            'Latency_ms': f"{latency_mean:.2f}±{latency_ci:.2f}" if not np.isnan(latency_ci) else f"{latency_mean:.2f}",
            'Δ_Latency_ms': f"{delta_latency:+.2f}",
            'Δ_Latency_Pct': f"{delta_latency_pct:+.1f}%",
            'CPU_%': f"{cpu_mean:.1f}",
            'Memory_%': f"{mem_mean:.1f}",
            'Δ_CPU': f"{delta_cpu:+.1f}",
            'Statistical_Power': f"{power:.3f}" if not np.isnan(power) else "N/A"
        }
        rows.append(row)

    df = pd.DataFrame(rows)

    csv_file = OUTPUT_DIR / "enhanced_comparison_table.csv"
    df.to_csv(csv_file, index=False)
    print(f"  Saved: {csv_file.name}")

    fig, ax = plt.subplots(figsize=(16, len(rows) * 0.8 + 2))
    ax.axis('tight')
    ax.axis('off')

    config_label_map = {
        'baseline': 'Baseline',
        'config1': 'Config 1 (NSG)',
        'config2': 'Config 2 (ASG)',
        'config3': 'Config 3 (Firewall)'
    }
    df['Configuration'] = df['Configuration'].map(lambda x: config_label_map.get(x, x))

    table = ax.table(cellText=df.values,
                     colLabels=df.columns,
                     cellLoc='center',
                     loc='center',
                     colWidths=[0.09, 0.04, 0.11, 0.10, 0.10, 0.08, 0.11, 0.11, 0.10, 0.10, 0.07, 0.07, 0.07, 0.10])

    table.auto_set_font_size(False)
    table.set_fontsize(7)
    table.scale(1, 2)

    for (i, j), cell in table.get_celld().items():
        if i == 0:
            cell.set_facecolor('#3498db')
            cell.set_text_props(weight='bold', color='white')
        else:
            if j == 0:
                cell.set_facecolor('#ecf0f1')
                cell.set_text_props(weight='bold')
            else:
                cell.set_facecolor('white')

    plt.title('Enhanced Statistical Comparison Table', fontsize=16, fontweight='bold', pad=20)
    plt.tight_layout()

    output_file = OUTPUT_DIR / "8_enhanced_comparison_table.png"
    plt.savefig(output_file, bbox_inches='tight')
    print(f"  Saved: {output_file.name}")
    plt.close()


def create_effect_size_analysis(all_data):
    """Creates effect size analysis visualization."""
    print("\n[9] Generating effect size analysis chart")

    if not all_data or 'baseline' not in all_data:
        print("  Need baseline data for effect size analysis")
        return

    config_order = ['config1', 'config2', 'config3']
    configs = [c for c in config_order if c in all_data]

    if not configs:
        print("  Need comparison configs for effect size analysis")
        return

    baseline = all_data['baseline']

    comparisons = []
    for config in configs:
        data = all_data[config]

        baseline_success = [it['overall_success_rate'] for it in baseline['attack_iterations']]
        config_success = [it['overall_success_rate'] for it in data['attack_iterations']]
        d_success = calculate_cohens_d(baseline_success, config_success)

        baseline_latency = [it['latency_avg'] for it in baseline['perf_iterations']]
        config_latency = [it['latency_avg'] for it in data['perf_iterations']]
        d_latency = calculate_cohens_d(baseline_latency, config_latency)

        baseline_cpu = [it['cpu_usage'] for it in baseline['perf_iterations']]
        config_cpu = [it['cpu_usage'] for it in data['perf_iterations']]
        d_cpu = calculate_cohens_d(baseline_cpu, config_cpu)

        comparisons.append({
            'Comparison': f"Baseline vs {config}",
            'Success_Rate_d': d_success,
            'Latency_d': d_latency,
            'CPU_d': d_cpu
        })

    df = pd.DataFrame(comparisons)

    csv_file = OUTPUT_DIR / "effect_size_analysis.csv"
    df.to_csv(csv_file, index=False)
    print(f"  Saved: {csv_file.name}")

    fig, axes = plt.subplots(1, 3, figsize=(15, 5))

    metrics = ['Success_Rate_d', 'Latency_d', 'CPU_d']
    titles = ['Lateral Movement Success Rate', 'Network Latency', 'CPU Usage']

    for ax, metric, title in zip(axes, metrics, titles):
        values = df[metric].values
        x = range(len(values))

        colors = []
        for v in values:
            abs_v = abs(v) if not np.isnan(v) else 0
            if abs_v < 0.2:
                colors.append('gray')
            elif abs_v < 0.5:
                colors.append('yellow')
            elif abs_v < 0.8:
                colors.append('orange')
            else:
                colors.append('red')

        bars = ax.bar(x, values, color=colors, alpha=0.7, edgecolor='black')

        ax.axhline(y=0, color='black', linestyle='-', linewidth=0.5)
        ax.axhline(y=0.2, color='gray', linestyle='--', linewidth=1, alpha=0.5)
        ax.axhline(y=-0.2, color='gray', linestyle='--', linewidth=1, alpha=0.5)
        ax.axhline(y=0.5, color='orange', linestyle='--', linewidth=1, alpha=0.5)
        ax.axhline(y=-0.5, color='orange', linestyle='--', linewidth=1, alpha=0.5)
        ax.axhline(y=0.8, color='red', linestyle='--', linewidth=1, alpha=0.5)
        ax.axhline(y=-0.8, color='red', linestyle='--', linewidth=1, alpha=0.5)

        for bar, val in zip(bars, values):
            if not np.isnan(val):
                ax.text(bar.get_x() + bar.get_width()/2., val,
                        f'{val:.2f}',
                        ha='center', va='bottom' if val > 0 else 'top', fontsize=10, fontweight='bold')

        ax.set_title(title, fontsize=11, fontweight='bold')
        ax.set_ylabel("Cohen's d", fontsize=10)
        ax.set_xticks(x)
        ax.set_xticklabels([f"vs\n{c.split()[-1]}" for c in df['Comparison']], fontsize=9)
        ax.grid(axis='y', alpha=0.3)

    plt.suptitle("Effect Size Analysis (Cohen's d)", fontsize=14, fontweight='bold')
    plt.tight_layout()

    output_file = OUTPUT_DIR / "9_effect_size_analysis.png"
    plt.savefig(output_file, bbox_inches='tight')
    print(f"  Saved: {output_file.name}")
    plt.close()


def create_power_analysis_table(all_data):
    """Creates statistical power analysis table."""
    print("\n[10] Generating statistical power analysis")

    if not all_data or 'baseline' not in all_data:
        print("  Need baseline data for power analysis")
        return

    config_order = ['config1', 'config2', 'config3']
    configs = [c for c in config_order if c in all_data]

    if not configs:
        print("  Need comparison configs for power analysis")
        return

    baseline = all_data['baseline']

    rows = []
    for config in configs:
        data = all_data[config]
        n = min(baseline['n'], data['n'])

        baseline_success = [it['overall_success_rate'] for it in baseline['attack_iterations']]
        config_success = [it['overall_success_rate'] for it in data['attack_iterations']]
        d_success = calculate_cohens_d(baseline_success, config_success)
        power_success = calculate_statistical_power(d_success, n)

        baseline_latency = [it['latency_avg'] for it in baseline['perf_iterations']]
        config_latency = [it['latency_avg'] for it in data['perf_iterations']]
        d_latency = calculate_cohens_d(baseline_latency, config_latency)
        power_latency = calculate_statistical_power(d_latency, n)

        rows.append({
            'Comparison': f"Baseline vs {config}",
            'n': n,
            'Success_Rate_d': f"{d_success:.3f}" if not np.isnan(d_success) else "N/A",
            'Success_Rate_Power': f"{power_success:.3f}" if not np.isnan(power_success) else "N/A",
            'Latency_d': f"{d_latency:.3f}" if not np.isnan(d_latency) else "N/A",
            'Latency_Power': f"{power_latency:.3f}" if not np.isnan(power_latency) else "N/A"
        })

    df = pd.DataFrame(rows)

    csv_file = OUTPUT_DIR / "statistical_power_analysis.csv"
    df.to_csv(csv_file, index=False)
    print(f"  Saved: {csv_file.name}")

    fig, ax = plt.subplots(figsize=(14, len(rows) * 0.8 + 2))
    ax.axis('tight')
    ax.axis('off')

    table = ax.table(cellText=df.values,
                     colLabels=df.columns,
                     cellLoc='center',
                     loc='center')

    table.auto_set_font_size(False)
    table.set_fontsize(9)
    table.scale(1, 2.5)

    for (i, j), cell in table.get_celld().items():
        if i == 0:
            cell.set_facecolor('#3498db')
            cell.set_text_props(weight='bold', color='white')
        else:
            if j == 0:
                cell.set_facecolor('#ecf0f1')
                cell.set_text_props(weight='bold')
            else:
                cell.set_facecolor('white')

    plt.title('Statistical Power Analysis', fontsize=16, fontweight='bold', pad=20)
    plt.tight_layout()

    output_file = OUTPUT_DIR / "10_statistical_power_analysis.png"
    plt.savefig(output_file, bbox_inches='tight')
    print(f"  Saved: {output_file.name}")
    plt.close()


def create_overhead_analysis(all_data):
    """Creates performance overhead analysis relative to baseline."""
    print("\n[11] Generating performance overhead analysis")

    if 'baseline' not in all_data:
        print("  No baseline data for overhead calculation")
        return

    baseline = all_data['baseline']
    baseline_latency = baseline['perf_metrics']['latency_avg']['mean']
    baseline_throughput = baseline['perf_metrics']['throughput']['mean']
    baseline_cpu = baseline['perf_metrics']['cpu_usage']['mean']
    baseline_memory = baseline['perf_metrics']['memory_usage']['mean']

    config_order = ['baseline', 'config1', 'config2', 'config3']
    configs = [c for c in config_order if c in all_data]

    rows = []
    for config in configs:
        data = all_data[config]

        config_latency = data['perf_metrics']['latency_avg']['mean']
        config_throughput = data['perf_metrics']['throughput']['mean']
        config_cpu = data['perf_metrics']['cpu_usage']['mean']
        config_memory = data['perf_metrics']['memory_usage']['mean']

        latency_overhead = calculate_performance_overhead(baseline_latency, config_latency, 'latency')
        throughput_overhead = calculate_performance_overhead(baseline_throughput, config_throughput, 'throughput')
        cpu_overhead = calculate_performance_overhead(baseline_cpu, config_cpu, 'other')
        memory_overhead = calculate_performance_overhead(baseline_memory, config_memory, 'other')

        row = {
            'Configuration': config,
            'Latency_ms': f"{config_latency:.2f}" if config_latency > 0 else "N/A",
            'Latency_Overhead_%': f"{latency_overhead:+.2f}%" if not np.isnan(latency_overhead) else "N/A",
            'Throughput_Mbps': f"{config_throughput:.2f}" if config_throughput > 0 else "N/A",
            'Throughput_Overhead_%': f"{throughput_overhead:+.2f}%" if not np.isnan(throughput_overhead) else "N/A",
            'CPU_%': f"{config_cpu:.1f}",
            'CPU_Overhead_%': f"{cpu_overhead:+.1f}%" if not np.isnan(cpu_overhead) else "N/A",
            'Memory_%': f"{config_memory:.1f}",
            'Memory_Overhead_%': f"{memory_overhead:+.1f}%" if not np.isnan(memory_overhead) else "0.0%"
        }
        rows.append(row)

    df = pd.DataFrame(rows)

    config_label_map = {
        'baseline': 'Baseline',
        'config1': 'Config 1 (NSG)',
        'config2': 'Config 2 (ASG)',
        'config3': 'Config 3 (Firewall)'
    }
    df['Configuration'] = df['Configuration'].map(lambda x: config_label_map.get(x, x))

    csv_file = OUTPUT_DIR / "performance_overhead_analysis.csv"
    df.to_csv(csv_file, index=False)
    print(f"  Saved: {csv_file.name}")

    fig, ax = plt.subplots(figsize=(14, len(rows) * 0.8 + 2))
    ax.axis('tight')
    ax.axis('off')

    table = ax.table(cellText=df.values, colLabels=df.columns,
                    cellLoc='center', loc='center')

    table.auto_set_font_size(False)
    table.set_fontsize(9)
    table.scale(1, 2.5)

    for (i, j), cell in table.get_celld().items():
        if i == 0:
            cell.set_facecolor('#3498db')
            cell.set_text_props(weight='bold', color='white')
        else:
            if j == 0:
                cell.set_facecolor('#ecf0f1')
                cell.set_text_props(weight='bold')
            else:
                cell.set_facecolor('white')

    plt.title('Performance Overhead Analysis (Relative to Baseline)', fontsize=16, fontweight='bold', pad=20)
    plt.tight_layout()

    output_file = OUTPUT_DIR / "11_performance_overhead_analysis.png"
    plt.savefig(output_file, bbox_inches='tight')
    print(f"  Saved: {output_file.name}")
    plt.close()


def export_individual_iterations(all_data):
    """Exports all individual iteration data for transparency."""
    print("\n[12] Exporting individual iteration data")

    all_rows = []

    for config_name, data in all_data.items():
        for i, (attack_it, perf_it) in enumerate(zip(data['attack_iterations'], data['perf_iterations']), 1):
            row = {
                'Configuration': config_name,
                'Iteration': i,
                'Success_Rate': attack_it['overall_success_rate'],
                'RDP_Success': attack_it['rdp_success_rate'],
                'SMB_Success': attack_it['smb_success_rate'],
                'Latency_Avg': perf_it['latency_avg'],
                'Latency_P95': perf_it['latency_p95'],
                'Latency_P99': perf_it['latency_p99'],
                'Throughput': perf_it['throughput'],
                'CPU_Usage': perf_it['cpu_usage'],
                'Memory_Usage': perf_it['memory_usage']
            }
            all_rows.append(row)

    df = pd.DataFrame(all_rows)

    csv_file = OUTPUT_DIR / "individual_iterations.csv"
    df.to_csv(csv_file, index=False)
    print(f"  Saved: {csv_file.name}")


# ============================================================================
# MAIN EXECUTION
# ============================================================================

def main():
    """Main execution function."""

    all_data = load_all_configurations()

    if not all_data:
        return

    print("\n" + "=" * 70)
    print("Generating Visualizations")
    print("=" * 70)

    create_lateral_movement_chart_with_ci(all_data)
    create_attack_breakdown_chart_with_ci(all_data)
    create_latency_chart_with_ci(all_data)
    create_throughput_chart_with_ci(all_data)
    create_resource_utilization_chart_with_ci(all_data)
    create_heatmap(all_data)

    print("\n" + "=" * 70)
    print("Generating Enhanced Statistical Outputs")
    print("=" * 70)

    create_enhanced_comparison_table(all_data)
    create_effect_size_analysis(all_data)
    create_power_analysis_table(all_data)
    create_overhead_analysis(all_data)
    export_individual_iterations(all_data)

    print("\n" + "=" * 70)
    print("Analysis Complete")
    print("=" * 70)
    print(f"\nOutput directory: {OUTPUT_DIR.absolute()}")
    print("\nGenerated files:")
    for file in sorted(OUTPUT_DIR.glob("*")):
        print(f"  {file.name}")
    print()


if __name__ == "__main__":
    main()

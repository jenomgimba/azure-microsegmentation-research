"""
Research Data Analysis Script for Azure Micro-Segmentation Study

Analyzes attack simulation and performance test results across 4 configurations.
Generates comparison tables, charts, and performs statistical analysis.

Usage: python analyze-results.py
Output: ./analysis-output/ directory
"""

import json
import os
from pathlib import Path
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats
from datetime import datetime

# Set publication-quality defaults for matplotlib
plt.rcParams['figure.dpi'] = 300
plt.rcParams['savefig.dpi'] = 300
plt.rcParams['font.size'] = 10
plt.rcParams['font.family'] = 'serif'
plt.rcParams['figure.figsize'] = (10, 6)

# Create output directory for analysis results
OUTPUT_DIR = Path("./analysis-output")
OUTPUT_DIR.mkdir(exist_ok=True)

print("=" * 70)
print("Data Analysis - Azure Micro-Segmentation Research")
print("=" * 70)


# ============================================================================
# SECTION 1: DATA LOADING AND PARSING
# ============================================================================

def find_json_files(base_dir, pattern):
    """
    Searches for JSON files matching a pattern.

    Args:
        base_dir: Directory to search
        pattern: String pattern in filename

    Returns:
        List of file paths
    """
    base_path = Path(base_dir)
    if not base_path.exists():
        return []

    files = list(base_path.glob(f"*{pattern}*.json"))
    if files:
        print(f"Found {len(files)} files in {base_dir}")
    return files


def load_attack_results():
    """
    Loads attack simulation results from JSON files.

    Returns:
        DataFrame with attack metrics
    """
    print("\n[1] Loading attack simulation results")

    search_locations = [
        "./AttackResults",
        "./ResearchData",
        "C:/AttackResults",
        "C:/ResearchData"
    ]

    all_files = []
    for location in search_locations:
        files = find_json_files(location, "attack-results")
        all_files.extend(files)

    if not all_files:
        print("No attack result files found")
        return pd.DataFrame()

    results = []
    for file_path in all_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)

            config = data.get('Configuration', 'unknown')
            metrics = data.get('Metrics', {})

            results.append({
                'Config': config,
                'Overall_Success_Rate': metrics.get('LateralMovementSuccessRate', 0),
                'RDP_Success_Rate': metrics.get('RDPSuccessRate', 0),
                'SMB_Success_Rate': metrics.get('SMBSuccessRate', 0),
                'Total_Attempts': metrics.get('TotalLateralMovementAttempts', 0),
                'Successful_Movements': metrics.get('SuccessfulLateralMovements', 0)
            })

            print(f"  Loaded {config}: {metrics.get('LateralMovementSuccessRate', 0)}% success rate")

        except Exception as e:
            print(f"  Error reading {file_path.name}: {e}")

    return pd.DataFrame(results)


def load_performance_results():
    """
    Loads performance test results from JSON files.

    Returns:
        DataFrame with performance metrics
    """
    print("\n[2] Loading performance test results")

    search_locations = [
        "./PerformanceResults",
        "./ResearchData",
        "C:/PerformanceResults",
        "C:/ResearchData"
    ]

    all_files = []
    for location in search_locations:
        files = find_json_files(location, "performance")
        all_files.extend(files)

    if not all_files:
        print("No performance result files found")
        return pd.DataFrame()

    results = []
    for file_path in all_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)

            config = data.get('Configuration', 'unknown')
            tests = data.get('Tests', {})

            latency = tests.get('NetworkLatency', {}).get('Statistics', {})
            throughput = tests.get('TCPThroughput', {})
            auth = tests.get('AuthenticationOverhead', {}).get('Statistics', {})
            resources = tests.get('ResourceUtilization', {})

            results.append({
                'Config': config,
                'Latency_Avg_ms': latency.get('Average', 0),
                'Latency_Min_ms': latency.get('Minimum', 0),
                'Latency_Max_ms': latency.get('Maximum', 0),
                'Latency_P95_ms': latency.get('P95', 0),
                'Latency_P99_ms': latency.get('P99', 0),
                'Throughput_Mbps': throughput.get('AverageThroughputMbps', 0),
                'Auth_Overhead_ms': auth.get('Average', 0),
                'CPU_Usage_Percent': resources.get('AverageCPU', 0),
                'Memory_Usage_Percent': resources.get('AverageMemory', 0)
            })

            print(f"  Loaded {config}: {latency.get('Average', 0):.2f}ms avg latency")

        except Exception as e:
            print(f"  Error reading {file_path.name}: {e}")

    return pd.DataFrame(results)


# ============================================================================
# SECTION 2: DATA VISUALIZATION
# ============================================================================

def create_lateral_movement_chart(df):
    """
    Creates bar chart comparing lateral movement success rates.

    Args:
        df: DataFrame with attack results
    """
    print("\n[3] Generating lateral movement success rate chart")

    if df.empty:
        print("  No data to plot")
        return

    # Sort by config order: baseline, config1, config2, config3
    config_order = ['baseline', 'config1', 'config2', 'config3']
    df['Config'] = pd.Categorical(df['Config'], categories=config_order, ordered=True)
    df = df.sort_values('Config')

    # Create figure
    fig, ax = plt.subplots(figsize=(10, 6))

    # Create bar chart
    colors = ['#d62728', '#ff7f0e', '#2ca02c', '#1f77b4']
    bars = ax.bar(df['Config'], df['Overall_Success_Rate'], color=colors, alpha=0.8, edgecolor='black')

    # Add value labels on bars
    for bar in bars:
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height,
                f'{height:.1f}%',
                ha='center', va='bottom', fontweight='bold', fontsize=11)

    # Customize chart
    ax.set_xlabel('Configuration', fontsize=12, fontweight='bold')
    ax.set_ylabel('Lateral Movement Success Rate (%)', fontsize=12, fontweight='bold')
    ax.set_title('Lateral Movement Success Rate by Configuration', fontsize=14, fontweight='bold', pad=20)
    ax.set_ylim(0, 100)
    ax.grid(axis='y', alpha=0.3, linestyle='--')

    # Add configuration labels
    config_labels = ['Baseline\n(Flat Network)', 'Config 1\n(NSG Segmentation)',
                     'Config 2\n(ASG Segmentation)', 'Config 3\n(Firewall + NSG + ASG)']
    ax.set_xticklabels(config_labels, fontsize=10)

    plt.tight_layout()
    output_file = OUTPUT_DIR / "1_lateral_movement_success_rates.png"
    plt.savefig(output_file, bbox_inches='tight')
    print(f"  Saved: {output_file.name}")
    plt.close()


def create_attack_breakdown_chart(df):
    """
    Creates grouped bar chart showing RDP vs SMB success rates.

    Args:
        df: DataFrame with attack results
    """
    print("\n[4] Generating attack method breakdown chart")

    if df.empty:
        print("  No data to plot")
        return

    # Sort configurations
    config_order = ['baseline', 'config1', 'config2', 'config3']
    df['Config'] = pd.Categorical(df['Config'], categories=config_order, ordered=True)
    df = df.sort_values('Config')

    # Create figure
    fig, ax = plt.subplots(figsize=(12, 6))

    # Set up grouped bars
    x = np.arange(len(df))
    width = 0.35

    bars1 = ax.bar(x - width/2, df['RDP_Success_Rate'], width, label='RDP',
                   color='#e74c3c', alpha=0.8, edgecolor='black')
    bars2 = ax.bar(x + width/2, df['SMB_Success_Rate'], width, label='SMB',
                   color='#3498db', alpha=0.8, edgecolor='black')

    # Add value labels
    for bars in [bars1, bars2]:
        for bar in bars:
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height,
                    f'{height:.0f}%',
                    ha='center', va='bottom', fontsize=9)

    # Customize chart
    ax.set_xlabel('Configuration', fontsize=12, fontweight='bold')
    ax.set_ylabel('Success Rate (%)', fontsize=12, fontweight='bold')
    ax.set_title('Lateral Movement Success Rate by Attack Method', fontsize=14, fontweight='bold', pad=20)
    ax.set_xticks(x)
    config_labels = ['Baseline', 'Config 1\n(NSG)', 'Config 2\n(ASG)', 'Config 3\n(Firewall)']
    ax.set_xticklabels(config_labels, fontsize=10)
    ax.set_ylim(0, 110)
    ax.legend(fontsize=11, loc='upper right')
    ax.grid(axis='y', alpha=0.3, linestyle='--')

    plt.tight_layout()
    output_file = OUTPUT_DIR / "2_attack_method_breakdown.png"
    plt.savefig(output_file, bbox_inches='tight')
    print(f"  Saved: {output_file.name}")
    plt.close()


def create_latency_comparison_chart(df):
    """
    Creates grouped bar chart comparing average latency with P95 and P99.

    Args:
        df: DataFrame with performance results
    """
    print("\n[5] Generating network latency comparison chart")

    if df.empty:
        print("  No data to plot")
        return

    # Sort configurations
    config_order = ['baseline', 'config1', 'config2', 'config3']
    df['Config'] = pd.Categorical(df['Config'], categories=config_order, ordered=True)
    df = df.sort_values('Config')

    # Create figure
    fig, ax = plt.subplots(figsize=(12, 6))

    # Set up grouped bars
    x = np.arange(len(df))
    width = 0.25

    bars1 = ax.bar(x - width, df['Latency_Avg_ms'], width, label='Average',
                   color='#2ecc71', alpha=0.8, edgecolor='black')
    bars2 = ax.bar(x, df['Latency_P95_ms'], width, label='P95',
                   color='#f39c12', alpha=0.8, edgecolor='black')
    bars3 = ax.bar(x + width, df['Latency_P99_ms'], width, label='P99',
                   color='#e74c3c', alpha=0.8, edgecolor='black')

    # Add value labels
    for bars in [bars1, bars2, bars3]:
        for bar in bars:
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height,
                    f'{height:.1f}',
                    ha='center', va='bottom', fontsize=8)

    # Customize chart
    ax.set_xlabel('Configuration', fontsize=12, fontweight='bold')
    ax.set_ylabel('Latency (milliseconds)', fontsize=12, fontweight='bold')
    ax.set_title('Network Latency Comparison Across Configurations', fontsize=14, fontweight='bold', pad=20)
    ax.set_xticks(x)
    config_labels = ['Baseline', 'Config 1\n(NSG)', 'Config 2\n(ASG)', 'Config 3\n(Firewall)']
    ax.set_xticklabels(config_labels, fontsize=10)
    ax.legend(fontsize=11, loc='upper left')
    ax.grid(axis='y', alpha=0.3, linestyle='--')

    plt.tight_layout()
    output_file = OUTPUT_DIR / "3_network_latency_comparison.png"
    plt.savefig(output_file, bbox_inches='tight')
    print(f"  Saved: {output_file.name}")
    plt.close()


def create_throughput_chart(df):
    """
    Creates bar chart comparing network throughput.

    Args:
        df: DataFrame with performance results
    """
    print("\n[6] Generating network throughput chart")

    if df.empty:
        print("  No data to plot")
        return

    # Sort configurations
    config_order = ['baseline', 'config1', 'config2', 'config3']
    df['Config'] = pd.Categorical(df['Config'], categories=config_order, ordered=True)
    df = df.sort_values('Config')

    # Create figure
    fig, ax = plt.subplots(figsize=(10, 6))

    # Create bar chart
    colors = ['#3498db', '#9b59b6', '#1abc9c', '#e67e22']
    bars = ax.bar(df['Config'], df['Throughput_Mbps'], color=colors, alpha=0.8, edgecolor='black')

    # Add value labels
    for bar in bars:
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height,
                f'{height:.1f}',
                ha='center', va='bottom', fontweight='bold', fontsize=11)

    # Customize chart
    ax.set_xlabel('Configuration', fontsize=12, fontweight='bold')
    ax.set_ylabel('Throughput (Mbps)', fontsize=12, fontweight='bold')
    ax.set_title('Network Throughput Comparison', fontsize=14, fontweight='bold', pad=20)
    ax.grid(axis='y', alpha=0.3, linestyle='--')

    config_labels = ['Baseline', 'Config 1\n(NSG)', 'Config 2\n(ASG)', 'Config 3\n(Firewall)']
    ax.set_xticklabels(config_labels, fontsize=10)

    plt.tight_layout()
    output_file = OUTPUT_DIR / "4_network_throughput.png"
    plt.savefig(output_file, bbox_inches='tight')
    print(f"  Saved: {output_file.name}")
    plt.close()


def create_resource_utilization_chart(df):
    """
    Creates grouped bar chart showing CPU and memory utilization.

    Args:
        df: DataFrame with performance results
    """
    print("\n[7] Generating resource utilization chart")

    if df.empty:
        print("  No data to plot")
        return

    # Sort configurations
    config_order = ['baseline', 'config1', 'config2', 'config3']
    df['Config'] = pd.Categorical(df['Config'], categories=config_order, ordered=True)
    df = df.sort_values('Config')

    # Create figure
    fig, ax = plt.subplots(figsize=(10, 6))

    # Set up grouped bars
    x = np.arange(len(df))
    width = 0.35

    bars1 = ax.bar(x - width/2, df['CPU_Usage_Percent'], width, label='CPU Usage',
                   color='#e74c3c', alpha=0.8, edgecolor='black')
    bars2 = ax.bar(x + width/2, df['Memory_Usage_Percent'], width, label='Memory Usage',
                   color='#3498db', alpha=0.8, edgecolor='black')

    # Add value labels
    for bars in [bars1, bars2]:
        for bar in bars:
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height,
                    f'{height:.1f}%',
                    ha='center', va='bottom', fontsize=9)

    # Customize chart
    ax.set_xlabel('Configuration', fontsize=12, fontweight='bold')
    ax.set_ylabel('Utilization (%)', fontsize=12, fontweight='bold')
    ax.set_title('Resource Utilization Comparison', fontsize=14, fontweight='bold', pad=20)
    ax.set_xticks(x)
    config_labels = ['Baseline', 'Config 1\n(NSG)', 'Config 2\n(ASG)', 'Config 3\n(Firewall)']
    ax.set_xticklabels(config_labels, fontsize=10)
    ax.set_ylim(0, 100)
    ax.legend(fontsize=11, loc='upper right')
    ax.grid(axis='y', alpha=0.3, linestyle='--')

    plt.tight_layout()
    output_file = OUTPUT_DIR / "5_resource_utilization.png"
    plt.savefig(output_file, bbox_inches='tight')
    print(f"  Saved: {output_file.name}")
    plt.close()


def create_heatmap(attack_df):
    """
    Creates heatmap showing attack success by configuration.

    Args:
        attack_df: DataFrame with attack results
    """
    print("\n[8] Generating attack success heatmap")

    if attack_df.empty:
        print("  No data to plot")
        return

    # Prepare data for heatmap
    config_order = ['baseline', 'config1', 'config2', 'config3']
    attack_df['Config'] = pd.Categorical(attack_df['Config'], categories=config_order, ordered=True)
    attack_df = attack_df.sort_values('Config')

    # Create matrix
    heatmap_data = attack_df[['Config', 'RDP_Success_Rate', 'SMB_Success_Rate']].set_index('Config')
    heatmap_data.columns = ['RDP', 'SMB']
    heatmap_data.index = ['Baseline', 'Config 1 (NSG)', 'Config 2 (ASG)', 'Config 3 (Firewall)']

    # Create figure
    fig, ax = plt.subplots(figsize=(8, 6))

    # Create heatmap
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
# SECTION 3: STATISTICAL ANALYSIS
# ============================================================================

def perform_statistical_tests(attack_df, perf_df):
    """
    Performs statistical analysis on results.

    Args:
        attack_df: DataFrame with attack results
        perf_df: DataFrame with performance results

    Returns:
        Dictionary with test results
    """
    print("\n[9] Performing statistical analysis")

    results = {}

    # Test 1: Compare baseline vs other configs for lateral movement success
    if not attack_df.empty and len(attack_df) >= 2:
        baseline = attack_df[attack_df['Config'] == 'baseline']['Overall_Success_Rate'].values
        others = attack_df[attack_df['Config'] != 'baseline']['Overall_Success_Rate'].values

        if len(baseline) > 0 and len(others) > 0:
            results['lateral_movement'] = {
                'baseline_mean': float(baseline.mean()),
                'others_mean': float(others.mean()),
                'reduction_percentage': float(((baseline.mean() - others.mean()) / baseline.mean()) * 100),
                'note': 'Single sample per config - descriptive statistics only'
            }

            print(f"  Lateral movement:")
            print(f"    Baseline: {baseline.mean():.2f}%")
            print(f"    Other configs average: {others.mean():.2f}%")
            print(f"    Reduction: {results['lateral_movement']['reduction_percentage']:.2f}%")

    # Test 2: Latency comparison
    if not perf_df.empty and len(perf_df) >= 2:
        baseline_latency = perf_df[perf_df['Config'] == 'baseline']['Latency_Avg_ms'].values
        others_latency = perf_df[perf_df['Config'] != 'baseline']['Latency_Avg_ms'].values

        if len(baseline_latency) > 0 and len(others_latency) > 0:
            results['latency'] = {
                'baseline_mean': float(baseline_latency.mean()),
                'others_mean': float(others_latency.mean()),
                'overhead_ms': float(others_latency.mean() - baseline_latency.mean()),
                'overhead_percentage': float(((others_latency.mean() - baseline_latency.mean()) / baseline_latency.mean()) * 100),
                'note': 'Single sample per config - descriptive statistics only'
            }

            print(f"  Latency:")
            print(f"    Baseline: {baseline_latency.mean():.2f}ms")
            print(f"    Other configs average: {others_latency.mean():.2f}ms")
            print(f"    Overhead: {results['latency']['overhead_ms']:.2f}ms ({results['latency']['overhead_percentage']:.2f}%)")

    return results


def create_summary_table(attack_df, perf_df, stats_results):
    """
    Creates comprehensive summary table.

    Args:
        attack_df: DataFrame with attack results
        perf_df: DataFrame with performance results
        stats_results: Dictionary from statistical tests
    """
    print("\n[10] Generating summary table")

    if attack_df.empty or perf_df.empty:
        print("  Insufficient data for summary table")
        return

    # Merge dataframes
    summary = pd.merge(attack_df, perf_df, on='Config', how='outer')

    # Sort configurations
    config_order = ['baseline', 'config1', 'config2', 'config3']
    summary['Config'] = pd.Categorical(summary['Config'], categories=config_order, ordered=True)
    summary = summary.sort_values('Config')

    # Select key columns
    table_data = summary[[
        'Config',
        'Overall_Success_Rate',
        'RDP_Success_Rate',
        'SMB_Success_Rate',
        'Latency_Avg_ms',
        'Latency_P95_ms',
        'Throughput_Mbps',
        'CPU_Usage_Percent'
    ]].copy()

    # Rename columns for display
    table_data.columns = [
        'Configuration',
        'Overall\nSuccess (%)',
        'RDP\nSuccess (%)',
        'SMB\nSuccess (%)',
        'Avg\nLatency (ms)',
        'P95\nLatency (ms)',
        'Throughput\n(Mbps)',
        'CPU\nUsage (%)'
    ]

    # Round numeric values
    numeric_cols = table_data.select_dtypes(include=[np.number]).columns
    table_data[numeric_cols] = table_data[numeric_cols].round(2)

    # Create figure
    fig, ax = plt.subplots(figsize=(14, 4))
    ax.axis('tight')
    ax.axis('off')

    # Create table
    table = ax.table(cellText=table_data.values,
                     colLabels=table_data.columns,
                     cellLoc='center',
                     loc='center',
                     colWidths=[0.15, 0.12, 0.12, 0.12, 0.12, 0.12, 0.12, 0.12])

    # Style the table
    table.auto_set_font_size(False)
    table.set_fontsize(9)
    table.scale(1, 2)

    # Header styling
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

    plt.title('Research Results Summary Table', fontsize=16, fontweight='bold', pad=20)

    plt.tight_layout()
    output_file = OUTPUT_DIR / "7_summary_table.png"
    plt.savefig(output_file, bbox_inches='tight')
    print(f"  Saved: {output_file.name}")
    plt.close()

    csv_file = OUTPUT_DIR / "summary_table.csv"
    table_data.to_csv(csv_file, index=False)
    print(f"  Saved: {csv_file.name}")


# ============================================================================
# SECTION 4: MAIN EXECUTION
# ============================================================================

def main():
    """
    Main execution function.
    """
    attack_results = load_attack_results()
    performance_results = load_performance_results()

    if attack_results.empty and performance_results.empty:
        print("\nNo data found. Expected locations:")
        print("  - C:/AttackResults/attack-results-*.json")
        print("  - C:/PerformanceResults/performance-*.json")
        return

    print("\n" + "=" * 70)
    print("Generating Visualizations")
    print("=" * 70)

    if not attack_results.empty:
        create_lateral_movement_chart(attack_results)
        create_attack_breakdown_chart(attack_results)
        create_heatmap(attack_results)

    if not performance_results.empty:
        create_latency_comparison_chart(performance_results)
        create_throughput_chart(performance_results)
        create_resource_utilization_chart(performance_results)

    print("\n" + "=" * 70)
    print("Statistical Analysis")
    print("=" * 70)

    stats_results = perform_statistical_tests(attack_results, performance_results)

    print("\n" + "=" * 70)
    print("Summary Table")
    print("=" * 70)

    create_summary_table(attack_results, performance_results, stats_results)

    print("\n" + "=" * 70)
    print("Analysis Complete")
    print("=" * 70)
    print(f"\nOutput directory: {OUTPUT_DIR.absolute()}")
    print("\nGenerated files:")
    for file in sorted(OUTPUT_DIR.glob("*.png")):
        print(f"  {file.name}")
    for file in sorted(OUTPUT_DIR.glob("*.csv")):
        print(f"  {file.name}")


if __name__ == "__main__":
    main()

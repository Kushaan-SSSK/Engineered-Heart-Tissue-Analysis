import pandas as pd
import os

# Paths
base = r'c:\Users\kusha\Downloads\11.11.25 EHT\EHT-scope-main'
old_results_map = {
    'Baseline (0 BPM)': os.path.join(base, 'D31_plate1_kushaan try_181125', 'Baseline', 'EHT_results_baseline'),
    '1 Hz (60 BPM)': os.path.join(base, 'D31_plate1_kushaan try_181125', '1hz', 'EHT_results_1hz'),
    '2 Hz (120 BPM)': os.path.join(base, 'D31_plate1_kushaan try_181125', '2hz', 'EHT_results_2hz')
}

new_results_map = {
    'Baseline (0 BPM)': os.path.join(base, 'Results', 'C3_0BPM_temp.txt_result.txt'),
    '1 Hz (60 BPM)': os.path.join(base, 'Results', 'C3_60BPM_temp.txt_result.txt'),
    '2 Hz (120 BPM)': os.path.join(base, 'Results', 'C3_120BPM_temp.txt_result.txt')
}

with open('comparison.txt', 'w') as f:
    f.write("=== Comparison: Old vs New Pipeline Results ===\n")
    f.write(f"{'Condition':<20} | {'Metric':<15} | {'Old Value':<10} | {'New Value':<10} | {'Diff Factor'}\n")
    f.write("-" * 80 + "\n")

def extract_val(df, col_name):
    if col_name in df.columns:
        return df[col_name].iloc[0]
    return float('nan')

for condition, old_path in old_results_map.items():
    new_path = new_results_map[condition]
    
    try:
        # Old Results are CSV (comma)
        df_old = pd.read_csv(old_path, sep=',')
        
        # New Results are TSV (tab)
        df_new = pd.read_csv(new_path, sep='\t')
        
        metrics = [
            ('syst_forces', 'Systolic Force'),
            ('dias_forces', 'Diastolic Force'),
            ('dev_forces', 'Developed Force'),
            ('beating_rates', 'Beat Rate'),
            ('beating_rates_std', 'Beat Rate Std'),
            ('dias_forc_st', 'Diastolic Std'),
            ('syst_forces_st', 'Systolic Std'),
            ('dev_forc_std', 'Developed Std'),
            ('t50', 'T50'),
            ('t50_std', 'T50 Std'),
            ('c50', 'C50'),
            ('c50_std', 'C50 Std'),
            ('r50', 'R50'),
            ('r50_std', 'R50 Std'),
            ('t2peak', 'T2Peak'),
            ('t2peak_std', 'T2Peak Std'),
            ('r90', 'R90'),
            ('r90_std', 'R90 Std'),
            ('uv', 'Up Velocity'),
            ('uv_std', 'Up Vel Std'),
            ('dv', 'Down Velocity'),
            ('dv_std', 'Down Vel Std')
        ]
        
        with open('comparison.txt', 'a') as f:
            f.write(f"[{condition}]\n")
            for col, label in metrics:
                val_old = extract_val(df_old, col)
                val_new = extract_val(df_new, col)
                
                factor = val_old / val_new if val_new != 0 else 0
                
                f.write(f"{'':<20} | {label:<15} | {val_old:<10.4f} | {val_new:<10.4f} | {factor:.2f}x\n")
            f.write("-" * 80 + "\n")
            
    except Exception as e:
        print(f"Error processing {condition}: {e}")


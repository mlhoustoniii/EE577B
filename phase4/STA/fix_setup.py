with open('.synopsys_pt.setup', 'w') as f:
    f.write('# PrimeTime session setup for cardinal_router STA\n')
    f.write('# EE 577B Spring 2026, Phase 4\n')
    f.write('set search_path  [list . ./libs ./designs ./sdc /tools/PDK/NCSU45PDK/FreePDK45/osu_soc/lib/files]\n')
    f.write('set link_path    [list * gscl45nm.db]\n')
    f.write('set target_library "gscl45nm.db"\n')
print("Done. Contents:")
with open('.synopsys_pt.setup') as f:
    for i, line in enumerate(f, 1):
        print(f"  {i}  {line}", end='')

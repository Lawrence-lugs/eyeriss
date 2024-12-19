import subprocess
import os
import sys
import pytest

sim_args = {'vcs':  [
                '-full64',
                '-debug_pp',
                '-sverilog',
                '+neg_tchk',
                '-l', 'vcs.log',
                '-R', '+lint=TFIPC-L',
                '+define+SYNOPSYS'
            ],
            'xrun': [
                '+access+r'
            ]
}

def test_cluster_synthesizability():

    design_name = 'cluster'
    log_file = f'tests/logs/{design_name}_synth.log'
    compile_tcl_path = f'compile.tcl'

    with open(log_file,'w+') as f:

        sim = subprocess.Popen([
            'dc_shell',
            '-f',
            compile_tcl_path,
        ], 
        shell=False,
        cwd='./synth',
        stdout=f,
        stdin=subprocess.PIPE,
        )

        # Need buffer in an exit to STDIN so it dc_shell quits on error
        sim.communicate(input=b'exit 1\n')

    assert not sim.wait(), get_log_tail(log_file,30)

def test_cluster_postsynth(simulator='vcs',seed=0):

    rtl_file_list = [
        '../mapped/mapped_PE_cluster.v'
    ]

    tb_name = 'tb_PE_cluster'
    tb_path = 'cluster'
    stimulus_output_path = f'tb/cluster/inputs'

    tb_file = f'../tb/{tb_path}/{tb_name}.sv'
    log_file = f'tests/logs/{tb_name}_{simulator}_postsynth.log'
    
    logdir = os.path.dirname(log_file)
    os.makedirs(logdir,exist_ok=True)

    # Pre-simulation

    from stimulus_gen import generate_tb_cluster_stimulus

    generate_tb_cluster_stimulus(
        actBits = 3,
        weightBits = 3,
        nActs = 16,
        nWeights = 3,
        seed = seed,
        path = stimulus_output_path
    )

    # Simulation

    import synlibs

    with open(log_file,'w+') as f:

        sim = subprocess.Popen([
            simulator,
            tb_file
        ] + sim_args[simulator] + rtl_file_list + synlibs.synthesis_verilog_files, 
        shell=False,
        cwd='./sims',
        stdout=f
        )

    assert not sim.wait(), get_log_tail(log_file,30)

    # Post-simulation

    with open(log_file,'r+') as f:
        f.seek(0)
        out = [line for line in f.readlines()]
        assert 'TEST SUCCESS\n' in out, get_log_tail(log_file,30)

    return



def get_log_tail(log_file,lines):
    with open(log_file,'r') as f:
        lines = f.readlines()[-lines:]
        return ''.join(lines)
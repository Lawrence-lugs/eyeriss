# content of conftest.py

valid_simulators = ['xrun','vcs']

def pytest_addoption(parser):
    parser.addoption(
        "--simulator",
        action="append",
        default=[],
        help="simulator to test with",
    )
    parser.addoption(
        "--synth",
        action="append",
        default=False,
        help="performs synthesis during tests",
    )
    parser.addoption(
        "--postsynth",
        action="store_true",
        default=False,
        help="performs post-synthesis simulation during tests",
    )

def pytest_generate_tests(metafunc):
    if "simulator" in metafunc.fixturenames:
        # Check if simulator is in supported
        for simulator in metafunc.config.getoption("simulator"):
            if simulator not in valid_simulators:
                raise ValueError(
                    f'Invalid simulator: {metafunc.config.getoption("simulator")}. Valid simulators: {valid_simulators}'
                )
        metafunc.parametrize("simulator", metafunc.config.getoption("simulator"))

    if 'seed' in metafunc.fixturenames:
        metafunc.parametrize("seed", metafunc.config.getoption("seed")[0])

    if 'synth' in metafunc.fixturenames:
        metafunc.parametrize("synth", metafunc.config.getoption("synth"))
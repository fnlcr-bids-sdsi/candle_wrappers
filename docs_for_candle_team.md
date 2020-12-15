# Documentation for the CANDLE team

## Terminology and scope

Below I call the scripts I'm describing in this document the "wrapper scripts" or "wrappers," but this still a working name. ("Interface" *may* be a viable alternative.) These scripts refer to the contents of the entire [wrappers GitHub repository](https://github.com/andrew-weisman/candle_wrappers), and I named them as such because the whole point was to add functionality to CANDLE while "wrapping" around the current Supervisor code, leaving it as untouched as possible so that it wouldn't interfere in any way with how people currently run CANDLE.

The wrapper scripts contain code that (1) helps to set up and test these scripts alongside new clones of the [Supervisor](https://github.com/ECP-CANDLE/Supervisor/tree/develop) and [Benchmarks](https://github.com/ECP-CANDLE/Benchmarks/tree/develop) CANDLE repos, and (2) enables the running of CANDLE by accessing a central installation of it. The documentation for setup (#1) can be found [here](./README.md); the documentation for usage (#2) is below.

## Overview of wrapper scripts functionality

### For users

* **Run CANDLE as a central installation**. E.g., instead of cloning the Supervisor and Benchmarks repos as usual and then running a Supervisor workflow directly in the `Supervisor/workflows/<WORKFLOW>/test` directory, you would go to any arbitrary directory on the filesystem, create or edit a single text file ("input file"), and call CANDLE with the input file as an argument. This is similar to how other large HPC-enabled software packages are run, e.g., software for calculating electronic structure
* **Edit only a single text input file** to modify *everything* you would need to set in order to run a job, e.g., workflow type, hyperparameter space, number of workers, walltime, "default model" settings, etc.
* **Minimally modify a bare model script**, e.g., no need to add `initialize_parameters()` and `run()` functions (whose content occassionally changes) to a new model that you'd like to run using CANDLE. The wrapper scripts still work for canonically CANDLE-compliant model scripts such as the already-written main `.py` files used to run benchmarks
  * An additional benefit to using the minimal modification procedure is that the output of the model using each hyperparameter set is put in its own file, `subprocess_out_and_err.txt`
* **Run model scripts written in other languages** such as `R` and `bash` (tested on Biowulf but not yet tested on Summit); minimal additions to the wrapper scripts are needed for adding additional language support
* **Perform a consistent workflow for testing and production jobs**, i.e.:
  1. *Testing:* Using `candle submit-job <INPUT-FILE>` with the input file keyword setting of `run_workflow=0` on an interactive node for testing modifications to a model script
  1. *Production:* Using `candle submit-job <INPUT-FILE>` this time with the default keyword setting of `run_workflow=1` on a login node for submitting a CANDLE job as usual
  * As long as the wrapper scripts are set up properly and your model script runs successfully using `run_workflow=0`, you can be pretty confident that submitting the job using `run_workflow=1` will pick up and run without dying

### For developers

* **Modify only a single file ([`candle_compliant_wrapper.py`](https://github.com/andrew-weisman/candle_wrappers/blob/master/commands/submit-job/candle_compliant_wrapper.py)) whenever the CANDLE-compliance procedure changes**. E.g., if the benchmarks used the minimal modification to the main `.py` files rather than the traditional CANDLE-compliance procedure, there would be no need to update every benchmark whenever the CANDLE-compliance procedure changed
* **Edit only a single file ([`preprocess.py`](https://github.com/andrew-weisman/candle_wrappers/blob/master/commands/submit-job/preprocess.py)) in order to make system-specific changes** such as custom modification to the `$TURBINE_LAUNCH_OPTIONS` variable; no need to edit each Supervisor workflow's `workflow.sh` file

## Loading the `candle` module

We are currently getting CANDLE approved as user-managed software on Summit. Once it is approved, we will be able to load the `candle` module via `module load candle/tf1`. In the interim, do this instead:

```bash
source /gpfs/alpine/med106/world-shared/candle/env_for_lmod-tf1.sh
```

Both methods primarily do the following:

* Sets the `$CANDLE` variable to `/gpfs/alpine/med106/world-shared/candle/tf1` in order to set the top-level directory of the entire CANDLE file tree, including the `Supervisor`, `Benchmarks`, and `wrappers` GitHub repositories
* Appends `$CANDLE/wrappers/bin` to `$PATH` in order to be able to run `candle` from the command line
* Sets the `$SITE` variable to `summit-tf1` in order to specify the HPC system and environment
* Appends `$CANDLE/Benchmarks/common` to `$PYTHONPATH` to allow one to write a Python model script in an arbitrary directory and to be able to run `import candle` in the script

## Quick-start examples (for Summit)

### Step 1: Setup

```bash
# Load the CANDLE module; do the following for the time being in lieu of "module load candle", as we are currently getting CANDLE approved as user-managed software
source /gpfs/alpine/med106/world-shared/candle/env_for_lmod-tf1.sh

# Enter a possibly empty directory that is completely outside of the Supervisor/Benchmarks repositories on the Alpine filesystem, such as $MEMBERWORK
cd /gpfs/alpine/med106/scratch/weismana/notebook/2020-11-13/testing_candle_installation
```

### Step 2: Run sample CANDLE-compliant models

This refers to model scripts that the developers refer to as "CANDLE-compliant" as usual (what I call "*canonically* CANDLE-compliant"). See [below](#how-a-canonically-candle-compliant-model-script-should-be-modified-for-use-with-the-wrapper-scripts) for the changes that should be made to canonically CANDLE-compliant scripts to get them to work with the wrapper scripts.

#### NT3 using UPF (CANDLE-compliant model scripts)

```bash
# Import the UPF example (one file will be copied over)
candle import-template upf

# Submit the job to the queue
candle submit-job upf_example.in
```

#### NT3 using mlrMBO (CANDLE-compliant model scripts)

```bash
# Import the mlrMBO example (two files will be copied over)
candle import-template mlrmbo

# Submit the job to the queue
candle submit-job mlrmbo_example.in
```

### Step 3: Run sample **non**-CANDLE-compliant model scripts

This refers to model scripts that have gone from "bare" (e.g., one downloaded directly from the Internet) to "minimally modified," a process described [below](#how-to-minimally-modify-a-bare-model-script-for-use-with-the-wrapper-scripts).

#### MNIST using UPF (non-CANDLE-compliant model scripts)

```bash
# Pre-fetch the MNIST data since Summit compute nodes can't access the Internet (this obviously has nothing to do with the wrapper scripts)
mkdir candle_generated_files
/gpfs/alpine/world-shared/med106/sw/condaenv-200408/bin/python -c "from keras.datasets import mnist; import os; (x_train, y_train), (x_test, y_test) = mnist.load_data(os.path.join(os.getcwd(), 'candle_generated_files', 'mnist.npz'))"

# Import the grid example (two files will be copied over)
candle import-template grid

# Submit the job to the queue
candle submit-job grid_example.in
```

#### NT3 using mlrMBO (non-CANDLE-compliant model scripts)

```bash
# Import the bayesian example (two files will be copied over)
candle import-template bayesian

# Submit the job to the queue
candle submit-job bayesian_example.in
```

## How a canonically CANDLE-compliant model script should be modified for use with the wrapper scripts

### Specifically required by the wrapper scripts, by example

```python
def initialize_parameters(default_model='nt3_default_model.txt'):

    import os # ADD THIS LINE

    nt3Bmk = bmk.BenchmarkNT3(
        bmk.file_path,
        # default_model, # ORIGINAL LINE
        os.getenv('CANDLE_DEFAULT_MODEL_FILE'), # NEW LINE
        'keras',
        prog='nt3_baseline',
        desc='1D CNN to classify RNA sequence data in normal or tumor classes')

    gParameters = candle.finalize_parameters(nt3Bmk)

    return gParameters
```

### Nothing to do with the wrapper scripts (generally no need to do these)

You may need to add `K.clear_session()` prior to, say, `model = Sequential()`. Otherwise, once the same rank runs a model script a *second* time, we get a strange `InvalidArgumentError` error that kills Supervisor (see the comments in [`$CANDLE/Benchmarks/Pilot1/NT3/nt3_candle_wrappers_baseline_keras2.py`](https://github.com/ECP-CANDLE/Benchmarks/blob/develop/Pilot1/NT3/nt3_candle_wrappers_baseline_keras2.py) for more details). It is wholly possible that this is a bug that has gotten fixed in subsequent versions of Keras/Tensorflow.

In addition, if you, say, pull a Benchmark model script out of the `Benchmarks` repository into your own separate directory, you may need to add a line like `sys.path.append(os.path.join(os.getenv('CANDLE'), 'Benchmarks', 'Pilot1', 'NT3'))`. This is demonstrated in [`$CANDLE/wrappers/examples/summit-tf1/mlrmbo/nt3_candle_wrappers_baseline_keras2.py`](https://github.com/andrew-weisman/candle_wrappers/blob/master/examples/summit-tf1/mlrmbo/nt3_candle_wrappers_baseline_keras2.py).

## How to minimally modify a bare model script for use with the wrapper scripts

1. Set the hyperparameters in the model script using a dictionary called `candle_params`
1. Ensure somewhere near the end of the script either the normal `history` object is defined or a metric of how well the hyperparameter set performed (a value you want to minimize, such as the loss evaluated on a test set) is returned as a number in the `candle_value_to_return` variable

This is demonstrated in [`$CANDLE/wrappers/examples/summit-tf1/grid/mnist_mlp.py`](https://github.com/andrew-weisman/candle_wrappers/blob/master/examples/summit-tf1/grid/mnist_mlp.py).

## Input file contents

The input file should contain three sections: `&control`, `&default_model`, and `&param_space`. Each section should start with this header on its own line and end with `/` on its own line. (This input file format is based on the [Quantum Espresso](https://www.quantum-espresso.org/) electronic structure software.) Four sample input files, corresponding to the four examples in the [quick-start examples above](#quick-start-examples-(for-summit)), are here: [upf](https://github.com/andrew-weisman/candle_wrappers/blob/master/examples/summit-tf1/upf/upf_example.in), [mlrmbo](https://github.com/andrew-weisman/candle_wrappers/blob/master/examples/summit-tf1/mlrmbo/mlrmbo_example.in), [grid](https://github.com/andrew-weisman/candle_wrappers/blob/master/examples/summit-tf1/grid/grid_example.in), [bayesian](https://github.com/andrew-weisman/candle_wrappers/blob/master/examples/summit-tf1/bayesian/bayesian_example.in). Spaces at the beginnings of the content-containing lines are optional and are recommended for readability.

### `&control` section

The `&control` section contains all settings aside from those specified in the `&default_model` and `&param_space` sections (detailed below) in the format `keyword = value`. Spaces around the `=` sign are optional, and each keyword setting should be on its own line. Each `value` ultimately gets interpreted by `bash` and hence is taken to be a string by default; thus, quotes are not necessary for string `value`s.

Here is a list of possible `keyword`s and their default `value`s (if `None`, then the keyword is required), as specified in [`$CANDLE/wrappers/site-specific_settings.sh`](https://github.com/andrew-weisman/candle_wrappers/blob/master/site-specific_settings.sh):

| `keyword`      | Default `value` | Notes |
| ----------- | ----------- | ----------- |
| `model_script`      | `None`       | Full path to the model script       |
| `workflow`   | `None`        | Currently only `grid` and `bayesian` are enabled (which get mapped to the UPF and mlrMBO Supervisor workflows)        |
| `project`   | `None`        | OLCF project to use, e.g., `med106`        |
| `walltime`   | `00:05`        | In `HH:MM` format as is used on Summit        |
| `nworkers`   | `1`        | workers=GPUs. The number of nodes used will be `nworkers` + (1 (`grid`) or 2 (`bayesian`)), after which 0-5 workers will be added in order to utilize all GPUs on all nodes        |
| `dl_backend`   | `keras`        | Valid backends are `keras` and `pytorch`        |
| `supp_modules`   | Empty string        | Supplementary `module`s to load prior to executing a model script (minimal CANDLE-compliance only)        |
| `python_bin_path`   | Empty string        | Actual Python version to use if not the one set in `env-$SITE.sh` (minimal CANDLE-compliance only)        |
| `exec_python_module`   | Empty string        | Actual Python `module` to use if not the Python version set in `env-$SITE.sh` (minimal CANDLE-compliance only)        |
| `supp_pythonpath`   | Empty string        | `:`-delimited list of `$PYTHONPATH` settings to append to the `$PYTHONPATH` variable (minimal CANDLE-compliance only)        |
| `extra_script_args`   | Empty string        | Extra arguments to the `python` or `R` programs to use when calling the corresponding model script (minimal CANDLE-compliance only)        |
| `exec_r_module`   | Empty string        | Actual R `module` to use if not the R version set in `env-$SITE.sh` (minimal CANDLE-compliance only)        |
| `supp_r_libs`   | Empty string        | Full path to a supplementary `$R_LIBS` library to use (minimal CANDLE-compliance only)        |
| `run_workflow`   | 1        | 0 will run your model script once using the default model parameters on the current node (so only use this on an interactive node); 1 will run the actual Supervisor workflow, submitting the job to the queue as usual        |
| `dry_run`   | 0        | 1 will set up the job but not execute it so that you can examine the settings files generated in the submission directory; 0 will run the job as usual         |
| `queue`   | `batch`        | Partition to use for the CANDLE job         |
| `default_model_file`   | Empty string        | Full path to the default model text file to use         |
| `param_space_file`   | Empty string        | Full path to the parameter space text file to use         |

### `&default_model` section

This can contain either a single keyword/value line containing the `candle_default_model_file` keyword pointing to the full path of the default model text file to use, e.g., `candle_default_model_file = $CANDLE/Benchmarks/Pilot1/NT3/nt3_default_model.txt` or the *contents* of such a default model file as, e.g., in the [grid](https://github.com/andrew-weisman/candle_wrappers/blob/master/examples/summit-tf1/grid/grid_example.in) or [bayesian](https://github.com/andrew-weisman/candle_wrappers/blob/master/examples/summit-tf1/bayesian/bayesian_example.in) examples in the [quick-start section above](#quick-start-examples-(for-summit)).

### `&param_space` section

This can contain either a single keyword/value line containing the `candle_param_space_file` keyword pointing to the full path of the file specifying the hyperparameter space to use, e.g., `candle_param_space_file = $CANDLE/Supervisor/workflows/mlrMBO/data/nt3_nightly.R` or the *contents* of such a parameter space file as, e.g., in the [grid](https://github.com/andrew-weisman/candle_wrappers/blob/master/examples/summit-tf1/grid/grid_example.in) or [upf](https://github.com/andrew-weisman/candle_wrappers/blob/master/examples/summit-tf1/upf/upf_example.in) examples in the [quick-start section above](#quick-start-examples-(for-summit)) or here:

```
&param_space
  makeDiscreteParam("batch_size", values = c(16, 32))
  makeIntegerParam("epochs", lower = 2, upper = 5)
  makeDiscreteParam("optimizer", values = c("adam", "sgd", "rmsprop", "adagrad", "adadelta"))
  makeNumericParam("dropout", lower = 0, upper = 0.9)
  makeNumericParam("learning_rate", lower = 0.00001, upper = 0.1)
/
```

## Code organization

A description of what every file does in the [wrappers repository](https://github.com/andrew-weisman/candle_wrappers), which is cloned to `$CANDLE/wrappers`, can be found [here](./repository_organization.md). Some particular notes:

* All documentation is currently in the top-level directory: `README.md` (see this file for additional notes), `docs_for_candle_team.md` (this file), `repository_organization.md`, `setup-biowulf.md`, and `setup-summit.md`
* Folders pertaining to the **setup** of the wrappers repository and in general of CANDLE on a new HPC system (involved in the [setup documentation](./README.md)) are `log_files`, `swift-t_setup`, and `test_files`
* Folders pertaining to the **usage** of the wrapper scripts (involved in the usage documentation that you are currently reading) are:
  * `lmod_modules`: contains `.lua` files used by the `lmod` system for loading `module`s, enabling one to run, e.g., [`module load candle`](#loading-the-`candle`-module)
  * `bin`: contains a single script called `candle` that can be accessed by typing `candle` on the command line once the CANDLE module has been loaded. You can generate a usage message by simply typing `candle` or `candle help` on the command line and hitting Enter
  * `examples`: contains sample/template input files and model scripts for different `$SITE`s
  * `commands`: contains one directory so-named for each command to the `candle` program, each containing all files related to the command. The file called `command_script.sh` in each command's folder is the main file called when the command is run using `candle <COMMAND> ...`. The only command not currently tested on Summit is `aggregate-results`. The bulk of the files involved in the functionality described in this document correspond to the `submit-job` command, i.e., are located in the `submit-job` folder
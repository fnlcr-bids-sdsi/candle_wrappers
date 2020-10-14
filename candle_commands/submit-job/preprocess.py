def check_keyword(keyword_key, possible_keywords_and_defaults, casting_func, is_valid, checked_keywords):
    """
    Check a given keyword in a robust, repeatable way.
    """

    # Import relevant library
    import os

    # If keyword_key is a possible keyword...
    if keyword_key in set(possible_keywords_and_defaults.keys()):

        # Obtain the keyword default value and from that whether it is required (if the default is None, then it must be required)
        keyword_default_value = possible_keywords_and_defaults[keyword_key]
        keyword_is_required = keyword_default_value is None

        # Load in the possible keyword value from the corresponding environment variable
        # If the variable is defined, we get a string, otherwise, we get None
        env_string = os.getenv('CANDLE_KEYWORD_'+keyword_key.upper())

        # If the keyword wasn't defined in the input file...
        if env_string is None:

            # If the keyword is required...
            if keyword_is_required:
                print('ERROR: Required keyword "{}" has not been set in the &control section of the input file'.format(keyword_key))
                exit(1)

            # If the keyword is optional...
            else:
                print('WARNING: Optional keyword "{}" has not been set in the &control section of the input file; it is being set to its default value of {}'.format(keyword_key, keyword_default_value))
                keyword_val = keyword_default_value

        # If the keyword WAS defined in the input file, then set its value to the appropriately casted, read-in value
        else:
            keyword_val = casting_func(env_string)

        # From the inputted is_valid() function, determine whether the keyword_val (whether read-in or the default value) is valid; if so...
        if is_valid(keyword_val):
            print('NOTE: Keyword "{}" has a valid value of {}'.format(keyword_key, keyword_val))
            checked_keywords[keyword_key] = keyword_val # update the running dictionary of checked keywords

        # If the keyword value is not actually valid...
        else:
            print('ERROR: Keyword "{}" has an invalid value of {}'.format(keyword_key, keyword_val))
            exit(1)

    # Return the running dictionary of checked keywords
    return(checked_keywords)


def no_validation(keyword_key):
    """
    Return a function always returning True in order to skip validation if desired.
    """
    print('WARNING: No error-checking done on "{}" keyword'.format(keyword_key))
    return(lambda keyword_val: True)


def dict_output(dict_to_output, message_to_output):
    """
    Output the contents of a dictionary in a visually appealing way.
    """

    # Get the maximum key length
    max_len = 0
    for key in dict_to_output.keys():
        if len(key) > max_len:
            max_len = len(key)

    # Construct the corresponding format string, with five spaces beyond the maximum key length
    format_str = '  {{:{}s}} {{}}'.format(max_len+5)

    # Output the desired message    
    print(message_to_output+'\n')

    # Output the dictionary key by key
    for key in dict_to_output.keys():
        print(format_str.format(key+':', dict_to_output[key]))


def check_keywords(possible_keywords_and_defaults_bash_var):
    """
    Check keywords from the input file.
    """

    # Import relevant library
    import os

    # Constants
    valid_workflows = ('grid', 'bayesian') # these are the CANDLE workflows (corresponding to upf and mlrMBO) that we've enabled so far

    # Initialize the running dictionary of checked keywords
    checked_keywords = dict()

    # Obtain Python dictionary of the possible keywords and their default values
    possible_keywords_and_defaults_str = os.getenv(possible_keywords_and_defaults_bash_var) # do this normally
    #possible_keywords_and_defaults_str = "{'model_script': None, 'workflow': None, 'walltime': '00:05', 'nworkers': 1, 'project': None}" # do this just for testing
    possible_keywords_and_defaults = eval(possible_keywords_and_defaults_str)

    # Output the possible keywords and their default values
    dict_output(possible_keywords_and_defaults, 'Possible keywords and their default values:')

    # Validate the model_script keyword
    def is_valid(keyword_val):
        try:
            with open(keyword_val):
                is_valid2 = True
        except IOError:
            print('WARNING: The file "{}" from the "model_script" keyword cannot be opened for reading'.format(keyword_val))
            is_valid2 = False
        return(is_valid2)
    checked_keywords = check_keyword('model_script', possible_keywords_and_defaults, str, is_valid, checked_keywords)

    # Validate the workflow keyword
    def is_valid(keyword_val):
        if keyword_val.lower() not in valid_workflows:
            print('WARNING: The "workflow" keyword ({}) in the &control section must be one of'.format(keyword_val), valid_workflows)
            is_valid2 = False
        else:
            is_valid2 = True
        return(is_valid2)
    checked_keywords = check_keyword('workflow', possible_keywords_and_defaults, str, is_valid, checked_keywords)

    # Validate the walltime keyword
    checked_keywords = check_keyword('walltime', possible_keywords_and_defaults, str, no_validation('walltime'), checked_keywords)

    # Validate the worker_type keyword
    def is_valid(keyword_val):
        valid_worker_types = eval(os.getenv('CANDLE_VALID_WORKER_TYPES'))
        if keyword_val.lower() not in valid_worker_types:
            print('WARNING: The "worker_type" keyword ({}) in the &control section must be one of'.format(keyword_val), valid_worker_types)
            is_valid2 = False
        else:
            is_valid2 = True
        return(is_valid2)
    checked_keywords = check_keyword('worker_type', possible_keywords_and_defaults, str, is_valid, checked_keywords)

    # Validate the nworkers keyword
    def is_valid(keyword_val):
        if keyword_val < 1:
            print('WARNING: The "nworkers" keyword ({}) in the &control section must be a positive integer'.format(keyword_val))
            is_valid2 = False
        else:
            is_valid2 = True
        return(is_valid2)
    checked_keywords = check_keyword('nworkers', possible_keywords_and_defaults, int, is_valid, checked_keywords)

    # Validate the nthreads keyword
    def is_valid(keyword_val):
        if keyword_val < 1:
            print('WARNING: The "nthreads" keyword ({}) in the &control section must be a positive integer'.format(keyword_val))
            is_valid2 = False
        else:
            is_valid2 = True
        return(is_valid2)
    checked_keywords = check_keyword('nthreads', possible_keywords_and_defaults, int, is_valid, checked_keywords)

    # Validate the custom_sbatch_args keyword
    checked_keywords = check_keyword('custom_sbatch_args', possible_keywords_and_defaults, str, no_validation('custom_sbatch_args'), checked_keywords)

    # Validate the mem_per_cpu keyword
    def is_valid(keyword_val):
        if keyword_val < 1:
            print('WARNING: The "mem_per_cpu" keyword ({}) in the &control section must be a positive integer (expressing memory size in GB)'.format(keyword_val))
            is_valid2 = False
        else:
            is_valid2 = True
        return(is_valid2)
    checked_keywords = check_keyword('mem_per_cpu', possible_keywords_and_defaults, int, is_valid, checked_keywords)

    # Validate the project keyword
    checked_keywords = check_keyword('project', possible_keywords_and_defaults, str, no_validation('project'), checked_keywords)

    # Output the checked keywords and their validated values
    dict_output(checked_keywords, 'Checked and validated keywords from the &control section of the input file:')

    return(checked_keywords)


def print_homog_job(ntasks, custom_sbatch_args, gres, mem_per_cpu, cpus_per_task, ntasks_per_core, partition, walltime, ntasks_per_node, nodes):
    ntasks_part = ' --ntasks={}'.format(ntasks)
    if custom_sbatch_args == '':
        custom_sbatch_args_part = ''
    else:
        custom_sbatch_args_part = ' {}'.format(custom_sbatch_args)
    if gres is not None:
        gres_part = ' --gres=gpu:{}:1'.format(gres)
    else:
        gres_part = ''
    mem_per_cpu_part = ' --mem-per-cpu={}G'.format(mem_per_cpu)
    cpus_per_task_part = ' --cpus-per-task={}'.format(cpus_per_task)
    ntasks_per_core_part = ' --ntasks-per-core={}'.format(ntasks_per_core)
    partition_part = ' --partition={}'.format(partition)
    walltime_part = ' --time={}'.format(walltime) # total run time of the job allocation
    ntasks_per_node_part = ' --ntasks-per-node={}'.format(ntasks_per_node)
    nodes_part = ' --nodes={}'.format(nodes)
    print('{}{}{}{}{}{}{}{}{}{}'.format(ntasks_part, gres_part, custom_sbatch_args_part, mem_per_cpu_part, cpus_per_task_part, ntasks_per_core_part, partition_part, walltime_part, ntasks_per_node_part, nodes_part))


def determine_sbatch_settings(workflow, walltime, worker_type, nworkers, nthreads, custom_sbatch_args, mem_per_cpu):
    # All settings below are based on task_assignment_summary.lyx/pdf on Andrew's computer for Biowulf

    import numpy as np

    # Already preprocessed parameters
    #workflow = 'grid'
    #walltime = '00:01:00'
    #custom_sbatch_args = ''
    #nworkers = 5
    #nthreads = 2
    #worker_type = 'cpu'

    # Contants
    ncores_cutoff = 16 # see more_cpus_tasks_etc.docx and cpus_tasks_etc.docx for justification
    ntasks_per_core = 1 # Biowulf suggests this for MPI jobs

    # Variables not needed to be customized
    W = nworkers
    if workflow == 'grid': # number of Swift/T processes S
        S = 1
    elif workflow == 'bayesian':
        S = 2

    # Variables to CONSIDER be customizable
    ntasks = W + S
    T = nthreads
    if worker_type == 'cpu': # CPU-only job
        gres = None
        nodes = int(np.ceil(ntasks*T/ncores_cutoff))
        ntasks_per_node = int(np.ceil(ntasks/nodes))

        if (ntasks_per_node*nodes) != ntasks:
            ntasks = ntasks_per_node * nodes # we may as well fill up all the resources we're allocating (can't do this for a GPU job, where we already ARE using all the resources [GPUs] we're allocating... remember we're reserving <nodes> GPUs)
            print('NOTE: Requested number of workers has automatically been increased from {} to {} in order to more efficiently use Biowulf\'s resources'.format(W,ntasks-S))

        if nodes == 1: # single-node job
            partition = 'norm'
        else: # multi-node job
            partition = 'multinode'
    else: # GPU job
        partition = 'gpu'
        gres = worker_type
        nodes = W
        ntasks_per_node = 1 + int(np.ceil(S/W))
    cpus_per_task = T

    # Print the sbatch command to work toward
    print('sbatch options that should be used:')
    print_homog_job(ntasks, custom_sbatch_args, gres, mem_per_cpu, cpus_per_task, ntasks_per_core, partition, walltime, ntasks_per_node, nodes)

    return(ntasks, gres, mem_per_cpu, cpus_per_task, ntasks_per_core, partition, ntasks_per_node, nodes)


def export_variables(workflow, ntasks, gres, custom_sbatch_args, mem_per_cpu, cpus_per_task, ntasks_per_core, partition, ntasks_per_node, nodes):

    f = open('preprocessed_vars_to_export.sh', 'w')

    # Export variables (well, print export statements for loading later) we'll need for later
    f.write('export WORKFLOW_TYPE={}\n'.format(workflow))
    f.write('export PROCS={}\n'.format(ntasks))
    if gres is not None:
        f.write('export TURBINE_SBATCH_ARGS="--gres=gpu:{}:1 {} --mem-per-cpu={}G --cpus-per-task={} --ntasks-per-core={} --nodes={}"\n'.format(gres, custom_sbatch_args, mem_per_cpu, cpus_per_task, ntasks_per_core, nodes))
        f.write('export TURBINE_LAUNCH_OPTIONS="--ntasks={} --distribution=cyclic"\n'.format(ntasks)) # should be fixed in the latest Swift/T so no need for a different variable name
    else:
        f.write('export TURBINE_SBATCH_ARGS="{} --mem-per-cpu={}G --cpus-per-task={} --ntasks-per-core={} --nodes={}"\n'.format(custom_sbatch_args, mem_per_cpu, cpus_per_task, ntasks_per_core, nodes))
    f.write('export QUEUE={}\n'.format(partition))
    f.write('export PPN={}\n'.format(ntasks_per_node))

    f.close()


# Check the input settings and return the resulting required and optional variables that we'll need later (all required variables are checked but not yet all optional variables)
workflow, walltime, worker_type, nworkers, nthreads, custom_sbatch_args, mem_per_cpu = check_keywords('CANDLE_POSSIBLE_KEYWORDS_AND_DEFAULTS')

# Determine the settings for the arguments to the sbatch, turbine, etc. calls
ntasks, gres, mem_per_cpu, cpus_per_task, ntasks_per_core, partition, ntasks_per_node, nodes = determine_sbatch_settings(workflow, walltime, worker_type, nworkers, nthreads, custom_sbatch_args, mem_per_cpu)

# Export variables we'll need later to a file in order to be sourced back in in run_workflows.sh
export_variables(workflow, ntasks, gres, custom_sbatch_args, mem_per_cpu, cpus_per_task, ntasks_per_core, partition, ntasks_per_node, nodes)

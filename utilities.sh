#!/bin/bash

# ASSUMPTIONS: candle module has been loaded
load_python_env() {

    # Load site-specific_settings.sh to get the $CANDLE_DEFAULT_PYTHON_MODULE value below
    # shellcheck source=/dev/null
    source "$CANDLE/wrappers/site-specific_settings.sh"

    if [ "x${CANDLE_DEFAULT_PYTHON_MODULE:0:1}" == "x/" ]; then # If $CANDLE_DEFAULT_PYTHON_MODULE actually contains a full path to the executable instead of a module name...
        path_to_add=$(dirname "$CANDLE_DEFAULT_PYTHON_MODULE")
        export PATH="$path_to_add:$PATH"
    else
        module load "$CANDLE_DEFAULT_PYTHON_MODULE"
    fi

    # If any extra arguments to load_python_env() are included, then set $PYTHONHOME as well
    if [ ! $# -eq 0 ]; then
        tmp="$(dirname "$(dirname "$(command -v python)")")"
        export PYTHONHOME="$tmp"
    fi
}


# ASSUMPTIONS: candle module has been loaded
unload_python_env() {

    # Load site-specific_settings.sh to get the $CANDLE_DEFAULT_PYTHON_MODULE value below
    # shellcheck source=/dev/null
    source "$CANDLE/wrappers/site-specific_settings.sh"

    if [ "x${CANDLE_DEFAULT_PYTHON_MODULE:0:1}" == "x/" ]; then # If $CANDLE_DEFAULT_PYTHON_MODULE actually contains a full path to the executable instead of a module name...
        path_to_remove=$(dirname "$CANDLE_DEFAULT_PYTHON_MODULE")
        tmp2="$(tmp=$(echo "$PATH" | awk -v RS=":" '{print}' | head -n -1 | grep -v "$path_to_remove" | awk -v ORS=":" '{print}'); echo "${tmp:0:${#tmp}-1}")"
        export PATH="$tmp2"
    else
        module unload "$CANDLE_DEFAULT_PYTHON_MODULE"
    fi

    # If any extra arguments to load_python_env() are included, then unset $PYTHONHOME as well
    if [ ! $# -eq 0 ]; then
        unset PYTHONHOME
    fi
}


# ASSUMPTIONS: candle module has been loaded
load_r_env() {
    # Load site-specific_settings.sh to get the $CANDLE_DEFAULT_R_MODULE value below
    # shellcheck source=/dev/null
    source "$CANDLE/wrappers/site-specific_settings.sh"

    if [ "x${CANDLE_DEFAULT_R_MODULE:0:1}" == "x/" ]; then # If $CANDLE_DEFAULT_R_MODULE actually contains a full path to the executable instead of a module name...
        path_to_add=$(dirname "$CANDLE_DEFAULT_R_MODULE")
        export PATH="$path_to_add:$PATH"
    else
        module load "$CANDLE_DEFAULT_R_MODULE"
    fi
}


# ASSUMPTIONS: candle module has been loaded
unload_r_env() {
    # Load site-specific_settings.sh to get the $CANDLE_DEFAULT_R_MODULE value below
    # shellcheck source=/dev/null
    source "$CANDLE/wrappers/site-specific_settings.sh"

    if [ "x${CANDLE_DEFAULT_R_MODULE:0:1}" == "x/" ]; then # If $CANDLE_DEFAULT_R_MODULE actually contains a full path to the executable instead of a module name...
        path_to_remove=$(dirname "$CANDLE_DEFAULT_R_MODULE")
        tmp2="$(tmp=$(echo "$PATH" | awk -v RS=":" '{print}' | head -n -1 | grep -v "$path_to_remove" | awk -v ORS=":" '{print}'); echo "${tmp:0:${#tmp}-1}")"
        export PATH="$tmp2"
    else
        module unload "$CANDLE_DEFAULT_R_MODULE"
    fi
}


# ASSUMPTIONS: The candle command has been called validly ($CANDLE_SUBMISSION_DIR is set in bin/candle)
make_generated_files_dir() {
    dirname="$CANDLE_SUBMISSION_DIR/candle_generated_files"
    [ -d "$dirname" ] || mkdir "$dirname"
}


# ASSUMPTIONS: The input model script is accessible
is_model_script_canonically_candle_compliant() {
    model_script=$1
    if (grep "^def run(" "$model_script" > /dev/null) && (grep "^def initialize_parameters(" "$model_script" > /dev/null); then
        #echo "model script is canonically CANDLE-compliant"
        exit 0
    else
        #echo "model script is NOT canonically CANDLE-compliant"
        exit 1
    fi
}

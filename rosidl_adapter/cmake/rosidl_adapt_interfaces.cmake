# Copyright 2018 Open Source Robotics Foundation, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# Convert non-idl interface files into `.idl` files.
#
# The input file might be a `.msg` or `.srv` file.
#
# :param idl_var: the variable name to return the list of generated `.idl`
#   files, each item is a tuple separated by a colon with an absolute base path
#   and a path relative to that base path
# :type idl_var: string
# :param arguments_file: the path of the arguments file containing the paths of
#   the non-idl files.
# :type arguments_file: string
# :param TARGET: the name of the generation target
# :type TARGET: string
#
# @public
#
function(rosidl_adapt_interfaces idl_var arguments_file)
  cmake_parse_arguments(ARG "" "TARGET" "NON_IDL_TUPLES"
    ${ARGN})
  if(ARG_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "rosidl_adapt_interfaces() called with unused "
      "arguments: ${ARG_UNPARSED_ARGUMENTS}")
  endif()

  find_package(Python3 REQUIRED COMPONENTS Interpreter)

  set(_output_dir "${CMAKE_CURRENT_BINARY_DIR}/rosidl_adapter/${PROJECT_NAME}")
  set(_idl_output "${CMAKE_CURRENT_BINARY_DIR}/rosidl_adapter/${ARG_TARGET}.idls")

  # Compute output .idl file paths at configure time.
  # The mapping is deterministic:
  #   input  "basepath:dir/Foo.msg" -> output "output_dir/dir/Foo.idl"
  #   tuple returned:                  "output_dir:dir/Foo.idl"
  set(_idl_adapter_tuples "")
  set(_idl_adapter_abs_files "")
  set(_non_idl_abs_files "")
  foreach(_tuple ${ARG_NON_IDL_TUPLES})
    string(REGEX REPLACE ":([^:]*)$" ";\\1" _tuple_parts "${_tuple}")
    list(GET _tuple_parts 0 _basepath)
    list(GET _tuple_parts 1 _relative_path)
    # Get the parent directory (msg, srv, action) and the stem
    get_filename_component(_parent_dir "${_relative_path}" DIRECTORY)
    get_filename_component(_stem "${_relative_path}" NAME_WE)
    set(_idl_relpath "${_parent_dir}/${_stem}.idl")
    set(_abs_idl_file "${_output_dir}/${_idl_relpath}")
    list(APPEND _idl_adapter_tuples "${_output_dir}:${_idl_relpath}")
    list(APPEND _idl_adapter_abs_files "${_abs_idl_file}")
    # Track the absolute source file for the DEPENDS clause
    list(APPEND _non_idl_abs_files "${_basepath}/${_relative_path}")
  endforeach()

  add_custom_command(
    OUTPUT ${_idl_adapter_abs_files} ${_idl_output}
    COMMAND Python3::Interpreter
    ARGS -m rosidl_adapter
      --package-name ${PROJECT_NAME}
      --arguments-file "${arguments_file}"
      --output-dir "${_output_dir}"
      --output-file "${_idl_output}"
    DEPENDS ${_non_idl_abs_files} "${arguments_file}"
    COMMENT "Adapting non-IDL interface files to .idl for ${PROJECT_NAME}"
    VERBATIM
  )

  set(_adapter_target "${ARG_TARGET}__rosidl_adapter")
  add_custom_target(${_adapter_target} DEPENDS ${_idl_adapter_abs_files})

  # Export the target name so that downstream generators can depend on it
  set(rosidl_adapt_interfaces_TARGET ${_adapter_target} PARENT_SCOPE)

  set(${idl_var} ${_idl_adapter_tuples} PARENT_SCOPE)
endfunction()

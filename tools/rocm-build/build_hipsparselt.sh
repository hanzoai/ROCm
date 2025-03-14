#!/bin/bash
set -ex
source "$(dirname "${BASH_SOURCE[0]}")/compute_helper.sh"
set_component_src hipSPARSELt
disable_debug_package_generation
if [ -n "$ENABLE_GPU_ARCH" ]; then
    set_gpu_arch "$ENABLE_GPU_ARCH"
else
    set_gpu_arch "all"
fi
while [ "$1" != "" ];
do
    case $1 in
        -o  | --outdir )
            shift 1; PKGTYPE=$1 ; TARGET="outdir" ;;
        -c  | --clean )
            TARGET="clean" ;;
        *)
            break ;;
    esac
    shift 1
done
build_hipsparselt() {
    echo "Start build"
    if [ "${ENABLE_STATIC_BUILDS}" == "true" ]; then
        ack_and_skip_static
    fi
    if [ "${ENABLE_ADDRESS_SANITIZER}" == "true" ]; then
       set_asan_env_vars
       set_address_sanitizer_on
    fi
    cd $COMPONENT_SRC
    mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
    init_rocm_common_cmake_params
    FC=gfortran \
    CXX=$(set_build_variables __HIP_CC__) \
    cmake \
        ${LAUNCHER_FLAGS} \
         "${rocm_math_common_cmake_params[@]}" \
        -DTensile_LOGIC= \
        -DTensile_CODE_OBJECT_VERSION=4 \
        -DTensile_CPU_THREADS= \
        -DTensile_LIBRARY_FORMAT=msgpack \
        -DBUILD_CLIENTS_SAMPLES=ON \
        -DBUILD_CLIENTS_TESTS=ON \
        -DBUILD_CLIENTS_BENCHMARKS=ON \
        -DCMAKE_INSTALL_PREFIX=${ROCM_PATH} \
        -DBUILD_ADDRESS_SANITIZER="${ADDRESS_SANITIZER}" \
        "$COMPONENT_SRC"
    cmake --build "$BUILD_DIR" -- -j${PROC}
    cmake --build "$BUILD_DIR" -- install
    cmake --build "$BUILD_DIR" -- package
    copy_if "${PKGTYPE}" "${CPACKGEN:-"DEB;RPM"}" "${PACKAGE_DIR}" "${BUILD_DIR}"/*."${PKGTYPE}"
    $SCCACHE_BIN -s || echo "Unable to display sccache stats"
}
clean_hipsparselt() {
    echo "Cleaning hipSPARSELt build directory: ${BUILD_DIR} ${PACKAGE_DIR}"
    rm -rf "$BUILD_DIR" "$PACKAGE_DIR"
    echo "Done!"
}
print_output_directory() {
    case ${PKGTYPE} in
        ("deb")
            echo ${DEB_PATH};;
        ("rpm")
            echo ${RPM_PATH};;
        (*)
            echo "Invalid package type \"${PKGTYPE}\" provided for -o" >&2; exit 1;;
    esac
    exit
}
case $TARGET in
    build) build_hipsparselt; build_wheel ;;
    outdir) print_output_directory ;;
    clean) clean_hipsparselt ;;
    *) die "Invalid target $TARGET" ;;
esac

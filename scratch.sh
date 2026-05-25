# Default flags
OPT_SETUP=false
OPT_BUILD=false
OPT_UPLOAD_DRIVE=false
OPT_UPLOAD_TESTFLIGHT=false

# Map legacy args to flags
if [ "$UPLOAD_ONLY_MODE" = true ]; then
    if [ "$TESTFLIGHT_MODE" = true ]; then
        OPT_UPLOAD_TESTFLIGHT=true
    else
        OPT_UPLOAD_DRIVE=true
    fi
    TARGET_ID="${UPLOAD_ONLY_ID}"
elif [ "$BUILD_ONLY_MODE" = true ]; then
    OPT_BUILD=true
    TARGET_ID="${BUILD_ONLY_ID}"
elif [ -n "$RUN_ID" ]; then
    OPT_SETUP=true
    OPT_BUILD=true
    OPT_UPLOAD_DRIVE=true
    TARGET_ID="$RUN_ID"
fi

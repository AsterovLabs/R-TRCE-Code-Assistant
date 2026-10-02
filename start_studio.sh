#!/usr/bin/env bash
# =============================================================================
# start_studio.sh -- Launcher for R-TRCE Code Assistant Interactive Studio
# =============================================================================
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$DIR/start_react_studio.sh" "$@"


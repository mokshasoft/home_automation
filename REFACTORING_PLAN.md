# Repository Refactoring Plan

## Current Structure

```
home_automation/
├── bb-image/                    # Generated BBB images
├── downloads/                   # Downloaded base images
├── mnt/                        # Mount point for image manipulation
├── systemd/                    # Empty directory (unused)
├── src/
│   ├── blink/                  # LED blink example (Python)
│   │   ├── led_blink.py
│   │   ├── led-blink.service
│   │   └── README.md
│   └── inverter/               # Mixed Python/Haskell implementations
│       ├── controller.py       # Python controller (OLD)
│       ├── growatt_rs485.py    # Python Modbus (OLD)
│       ├── main.py            # Python main (OLD)
│       ├── switch.py          # Python GPIO (OLD)
│       ├── growatt-mqtt.service
│       ├── flake.nix, pyproject.toml, uv.lock
│       ├── .env, Makefile
│       └── hs/                # Haskell implementation (CURRENT)
│           ├── src/
│           ├── app/
│           ├── flake.nix
│           └── ...
├── Makefile                   # Image creation
├── flake.nix                  # Top-level Nix config
└── MAX Series Modbus RTU Protocol.pdf
```

## Proposed Structure

```
home_automation/
├── bb-image/                  # Generated BBB images (keep)
├── downloads/                 # Downloaded base images (keep)
├── mnt/                      # Mount point (keep)
├── app/
│   ├── blink/                # LED blink example
│   │   ├── led_blink.py
│   │   ├── led-blink.service
│   │   └── README.md
│   ├── controller/           # Active Haskell controller
│   │   ├── src/             # Haskell source files
│   │   ├── app/             # Haskell executables
│   │   ├── flake.nix
│   │   ├── stack.yaml
│   │   ├── growatt-controller.cabal
│   │   ├── Makefile
│   │   ├── growatt-controller.service  # systemd service file
│   │   └── README.md
│   └── old/
│       └── controller/       # Archived Python implementation
│           ├── controller.py
│           ├── growatt_rs485.py
│           ├── main.py
│           ├── switch.py
│           ├── growatt-mqtt.service
│           ├── flake.nix
│           ├── pyproject.toml
│           ├── uv.lock
│           ├── .env
│           ├── Makefile
│           └── README.md (to be created)
├── docs/                     # Documentation
│   └── MAX Series Modbus RTU Protocol.pdf
├── Makefile                  # Updated image creation
├── flake.nix                 # Top-level Nix config
└── README.md                 # Updated repository README
```

## Rationale

### Why Rename `src/` → `app/`?
- `app/` better describes deployable applications
- Clearer distinction from library source code
- Industry convention for application-level projects

### Why Flatten `inverter/hs/` → `controller/`?
- Removes unnecessary nesting
- "controller" is more descriptive than generic "inverter"
- Matches the actual purpose (controlling inverter-based switches)
- Cleaner paths in imports and documentation

### Why Archive Python Implementation?
- Haskell implementation is the current/active version
- Python code should be preserved for reference
- Clear separation prevents confusion
- Easier to remove entirely later if never needed

### Why Create `docs/` Directory?
- Centralizes documentation
- PDF protocol reference logically belongs with docs
- Cleaner root directory

## Migration Steps

### Phase 1: Preparation
1. **Create branch** for refactoring work
2. **Verify all tests pass** on current structure
3. **Tag current state** for rollback if needed

### Phase 2: Create New Structure
1. Create `app/` directory
2. Create `app/old/controller/` directory structure
3. Create `docs/` directory

### Phase 3: Move Active Code
1. Move `src/blink/` → `app/blink/`
2. Move `src/inverter/hs/` → `app/controller/`
3. Create `app/controller/growatt-controller.service` systemd unit file
4. Verify Haskell build still works

### Phase 4: Archive Python Code
1. Copy Python files to `app/old/controller/`:
   - controller.py
   - growatt_rs485.py
   - main.py
   - switch.py
   - growatt-mqtt.service
   - flake.nix
   - pyproject.toml
   - uv.lock
   - .env
   - Makefile
2. Create README.md explaining deprecation
3. Remove Python files from `src/inverter/`

### Phase 5: Update References
1. Update root `Makefile`:
   - Change `src/blink/` references to `app/blink/`
   - Update controller paths to use Haskell implementation
   - Add `controller-service` target to install Haskell controller
   - Remove Python MQTT service installation (`growatt-mqtt` target)
   - Update `create-bbb-image` dependencies
2. Update root `flake.nix` if needed
3. Update root `.gitignore` for new structure

### Phase 6: Documentation
1. Move PDF to `docs/`
2. Create/update root README.md
3. Update all internal documentation references
4. Add deprecation notice to archived Python code

### Phase 7: Cleanup
1. Remove empty `src/` directory
2. Remove empty `systemd/` directory
3. Verify nothing references old paths
4. Test image creation workflow

### Phase 8: Testing
1. Test `make format && make lint && stack build` in `app/controller/`
2. Test BBB image creation: `make create-bbb-image`
3. Verify all paths resolve correctly
4. Test deployment workflow

## Detailed File Movements

### Keep in Place (No Changes)
- `bb-image/`
- `downloads/`
- `mnt/`
- `.git/`
- `.gitignore` (may need updates)
- `LICENSE`

### Move Operations
```bash
# LED blink
src/blink/ → app/blink/

# Haskell controller
src/inverter/hs/ → app/controller/

# Python controller (archive)
src/inverter/*.py → app/old/controller/
src/inverter/growatt-mqtt.service → app/old/controller/
src/inverter/flake.nix → app/old/controller/
src/inverter/pyproject.toml → app/old/controller/
src/inverter/uv.lock → app/old/controller/
src/inverter/.env → app/old/controller/
src/inverter/Makefile → app/old/controller/

# Documentation
MAX Series Modbus RTU Protocol.pdf → docs/
```

### Remove After Migration
- `src/` directory (should be empty)
- `systemd/` directory (already empty)

## Systemd Service Requirements

Each application deployed to the BBB image **must** include its systemd service file within its own directory. This ensures:
- Self-contained applications
- Easy deployment and maintenance
- Clear service configuration co-located with code

### Service File Location
- **LED Blink**: `app/blink/led-blink.service` (already exists)
- **Haskell Controller**: `app/controller/growatt-controller.service` (to be created)
- **Python Controller (archived)**: `app/old/controller/growatt-mqtt.service` (preserved)

### Service File Requirements
Each service file should:
1. Define proper `[Unit]` section with description
2. Specify executable path in `[Service]` section
3. Set appropriate `User`, `WorkingDirectory`, and `Restart` policies
4. Include `[Install]` section with `WantedBy=multi-user.target`
5. Document any environment variables or configuration files needed

## Updated Makefile Targets

### Current Reference (to be replaced)
```makefile
led-service:
    sudo cp src/blink/led_blink.py $(MOUNT_DIR)/opt/bbb/
    sudo cp src/blink/led-blink.service $(MOUNT_DIR)/etc/systemd/system/

growatt-mqtt:
    sudo cp src/inverter/growatt_mqtt.py $(MOUNT_DIR)/opt/bbb/
    sudo cp src/inverter/growatt-mqtt.service $(MOUNT_DIR)/etc/systemd/system/
```

### New Reference
```makefile
led-service:
    @echo "Installing LED blink service..."
    sudo cp app/blink/led_blink.py $(MOUNT_DIR)/opt/bbb/
    sudo chmod +x $(MOUNT_DIR)/opt/bbb/led_blink.py
    sudo cp app/blink/led-blink.service $(MOUNT_DIR)/etc/systemd/system/
    sudo chroot $(MOUNT_DIR) $(QEMU_BIN) /bin/bash -c "systemctl enable led-blink.service"

controller-service:
    @echo "Installing Haskell controller service..."
    # Build the controller first
    cd app/controller && stack build
    # Copy executable to image
    sudo mkdir -p $(MOUNT_DIR)/opt/bbb
    sudo cp app/controller/.stack-work/install/x86_64-linux-tinfo6/.../bin/controller $(MOUNT_DIR)/opt/bbb/growatt-controller
    sudo chmod +x $(MOUNT_DIR)/opt/bbb/growatt-controller
    # Copy and enable service
    sudo cp app/controller/growatt-controller.service $(MOUNT_DIR)/etc/systemd/system/
    sudo chroot $(MOUNT_DIR) $(QEMU_BIN) /bin/bash -c "systemctl enable growatt-controller.service"

# Update the main target
create-bbb-image: download unpack mount setup-resolv broker led-service controller-service unmount
    @echo "Wrote BeagleBone Black image to $(TARGET_IMG)"
```

## Git Operations

### Branching Strategy
```bash
# Create refactoring branch
git checkout -b refactor/reorganize-repository

# After all changes
git add -A
git commit -m "Refactor: Reorganize repository structure

- Rename src/ to app/ for clarity
- Move Haskell controller from src/inverter/hs/ to app/controller/
- Archive Python implementation to app/old/controller/
- Move documentation to docs/ directory
- Update all references in Makefile and configs
- Remove empty directories"

# Merge to main after review
git checkout main
git merge refactor/reorganize-repository
```

## Rollback Plan

If issues arise:
1. Git has full history - can revert commit
2. Tagged state allows easy recovery
3. Python code preserved in archive
4. No data loss, only reorganization

## Benefits

### Immediate Benefits
- **Clearer structure**: Purpose of each directory obvious
- **Reduced confusion**: One active implementation clearly identified
- **Better organization**: Related code grouped logically
- **Cleaner paths**: Fewer nested directories

### Long-term Benefits
- **Easier maintenance**: Changes isolated to relevant directories
- **Better onboarding**: New contributors understand layout quickly
- **Scalable**: Can add new applications under app/ cleanly
- **Professional**: Follows industry conventions

## Risks & Mitigations

### Risk: Breaking Existing Workflows
**Mitigation**: Update all scripts and documentation in same commit

### Risk: Lost References
**Mitigation**: Use git history, preserve archived code

### Risk: Build Failures
**Mitigation**: Test thoroughly before committing, use git branches

### Risk: Documentation Drift
**Mitigation**: Update all README files as part of refactoring

## Timeline Estimate

- **Preparation**: 5 minutes
- **File movements**: 10 minutes
- **Update references**: 15 minutes
- **Documentation**: 15 minutes
- **Testing**: 20 minutes
- **Total**: ~1 hour

## Verification Checklist

- [ ] All files moved correctly
- [ ] No broken symlinks
- [ ] Systemd service file created for Haskell controller
- [ ] Service file includes all required sections
- [ ] Haskell build succeeds: `cd app/controller && make format && make lint && stack build`
- [ ] Image creation works: `make create-bbb-image`
- [ ] Controller service properly installed in image
- [ ] Service enabled in systemd
- [ ] All READMEs updated with service documentation
- [ ] All Makefile paths updated
- [ ] Git history clean
- [ ] No uncommitted changes
- [ ] All tests pass

## Systemd Service File Template

The `app/controller/growatt-controller.service` should follow this template:

```ini
[Unit]
Description=Growatt Inverter Controller (Haskell)
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/bbb
ExecStart=/opt/bbb/growatt-controller
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Resource limits
MemoryLimit=256M
CPUQuota=50%

[Install]
WantedBy=multi-user.target
```

### Service File Documentation

Each application's README should document:
1. How to view logs: `journalctl -u growatt-controller.service -f`
2. How to start/stop: `systemctl start/stop growatt-controller.service`
3. How to check status: `systemctl status growatt-controller.service`
4. How to disable: `systemctl disable growatt-controller.service`
5. Configuration requirements (ports, GPIO pins, etc.)

## Post-Refactoring Tasks

1. Create systemd service file for Haskell controller
2. Test service file on actual BBB hardware
3. Update CI/CD pipelines (if any)
4. Update deployment documentation
5. Notify team of new structure
6. Archive old branch for reference
7. Consider removing archived Python code after 6 months if unused

## Notes

- Preserve all git history through moves
- Use `git mv` for tracked files
- Maintain .gitignore patterns
- Keep commit atomic - one refactoring commit
- Test on a branch first

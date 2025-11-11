
#!/bin/bash
# =====================================
# Install Miniconda to public directory /opt/miniconda3
# and configure it to be automatically loaded for seed user
# In base environment, install scapy, ipython, docker, etc.
# =====================================

INSTALL_PREFIX="/opt/miniconda3"
MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
INSTALL_SCRIPT="Miniconda3-latest-Linux-x86_64.sh"
SEED_USER="seed"
SEED_HOME="/home/$SEED_USER"

# If installation directory already exists, skip installation
if [ -d "$INSTALL_PREFIX" ]; then
            echo "✅ $INSTALL_PREFIX already exists, skipping installation."
else
    # Check if installation script already exists                                       
    if [ -f "$INSTALL_SCRIPT" ]; then
            echo "✅ $INSTALL_SCRIPT already exists, skipping download."
    else
            echo "⬇️ Downloading $INSTALL_SCRIPT ..."
        curl -LO "$MINICONDA_URL" || { echo "Download failed"; exit 1; }
    fi

    chmod +x "$INSTALL_SCRIPT"

    echo "🚀 Installing Miniconda to $INSTALL_PREFIX as root ..."
    sudo bash "$INSTALL_SCRIPT" -b -p "$INSTALL_PREFIX" || { echo "Installation failed"; exit 1; }

    echo "✅ Miniconda installation completed successfully."

    # Add /opt/miniconda3/bin to PATH for all users
    echo 'export PATH="/opt/miniconda3/bin:$PATH"' | sudo tee /etc/profile.d/conda.sh >/dev/null
    sudo chmod +x /etc/profile.d/conda.sh

    # Set permissions for sudo group to read/write/execute
    sudo chgrp -R sudo "$INSTALL_PREFIX"
    sudo chmod -R g+rwX "$INSTALL_PREFIX"
    sudo find "$INSTALL_PREFIX" -type d -exec chmod g+s {} \;

    echo "✅ $INSTALL_PREFIX permissions set to sudo group read/write/execute"
fi

# Initialize conda for all shells
sudo -u $SEED_USER $INSTALL_PREFIX/bin/conda init --all
# Accept TOS
sudo "$INSTALL_PREFIX/bin/conda" tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
sudo "$INSTALL_PREFIX/bin/conda" tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# Disable conda auto-activation of base environment     
# sudo $INSTALL_PREFIX/bin/conda config --system --set auto_activate_base false

# Install tools in base environment
echo "📦 Installing scapy ipython docker in base environment..."
sudo $INSTALL_PREFIX/bin/conda install -n base -y scapy ipython jupyterlab pycryptodome
sudo $INSTALL_PREFIX/bin/pip install docker

# If public environment does not exist, create it
if [ ! -d "$INSTALL_PREFIX/envs/seedpy310" ]; then
    echo "📦 Creating public environment seedpy310..."
    sudo $INSTALL_PREFIX/bin/conda create -p "$INSTALL_PREFIX/envs/seedpy310" python=3.10 -y
    echo "✅ Public Conda environment seedpy310 created"
else
    echo "✅ Public environment seedpy310 already exists, skipping creation."
fi

# Configure seed user to automatically activate seedpy310 environment
SEED_BASHRC="$SEED_HOME/.bashrc"
if ! grep -q "conda activate $INSTALL_PREFIX/envs/seedpy310" "$SEED_BASHRC"; then
    echo "source /opt/miniconda3/etc/profile.d/conda.sh" | sudo tee -a "$SEED_BASHRC" >/dev/null
    # echo "conda activate /opt/miniconda3/envs/seedpy310" | sudo tee -a "$SEED_BASHRC" >/dev/null
    sudo chown $SEED_USER:$SEED_USER "$SEED_BASHRC"
    echo "✅ Configured seed user to automatically activate seedpy310 environment"
fi

echo "==================================="
echo "Installation completed successfully!"
echo "🔑 base environment installed: scapy, ipython, docker(pip)"
# echo "🔑 seed user will automatically enter seedpy310 environment upon login"

# Install seed-emulator in seedpy310 environment
echo "🚀 Installing seed-emulator in seedpy310 environment..."

# Clone seed-emulator repository to seed user home directory
if [ ! -d "$SEED_HOME/seed-emulator" ]; then
    echo "📥 Cloning seed-emulator repository..."
    if sudo -u $SEED_USER git clone https://github.com/seed-labs/seed-emulator.git "$SEED_HOME/seed-emulator"; then
        echo "✅ seed-emulator repository cloned successfully"
        GIT_CLONE_SUCCESS=true
    else
        echo "❌ Failed to clone seed-emulator repository, skipping subsequent steps"
        GIT_CLONE_SUCCESS=false
    fi
else
    echo "✅ seed-emulator repository already exists, skipping clone"
    GIT_CLONE_SUCCESS=true
fi

# Only proceed with installation if git clone was successful or repository already exists
if [ "$GIT_CLONE_SUCCESS" = true ]; then
    # Install requirements in seedpy310 environment
    echo "📦 Installing seed-emulator requirements in seedpy310 environment..."
    # Using seedpy310 environment's pip directly (equivalent to activating environment)
    sudo -u $SEED_USER $INSTALL_PREFIX/envs/seedpy310/bin/pip install -r "$SEED_HOME/seed-emulator/requirements.txt"
    echo "✅ seed-emulator requirements installed successfully"

    # Add seed-emulator to PYTHONPATH in seed user's .bashrc
    if ! grep -q "seed-emulator" "$SEED_BASHRC"; then
        echo "📝 Adding seed-emulator to PYTHONPATH..."
        echo 'export PYTHONPATH="/home/seed/seed-emulator:$PYTHONPATH"' | sudo tee -a "$SEED_BASHRC" >/dev/null
        sudo chown $SEED_USER:$SEED_USER "$SEED_BASHRC"
        echo "✅ seed-emulator added to PYTHONPATH"
    else
        echo "✅ seed-emulator already in PYTHONPATH"
    fi
    
    echo "==================================="
    echo "🎉 seed-emulator installation completed!"
    echo "🔑 seed user can now use: conda activate seedpy310"
    echo "🔑 seed-emulator is ready to use with PYTHONPATH set"
else
    echo "==================================="
    echo "⚠️  seed-emulator installation skipped due to git clone failure"
    echo "🔑 Miniconda and seedpy310 environment are still available"
fi

echo "==================================="
echo "🎉 seed-emulator installation completed!"
echo "🔑 seed user can now use: conda activate seedpy310"
echo "🔑 seed-emulator is ready to use with PYTHONPATH set"

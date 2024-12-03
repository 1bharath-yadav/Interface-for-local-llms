## Ollama

Ollama is a lightweight Android app that serves as an intuitive interface for running Meta's large language models directly on your device through Termux. With support for Meta's LLaMA 2.3 models (1B and 3B parameters), Ollama transforms your smartphone into a powerful AI assistant, requiring just 1GB to 2GB of RAM for seamless operation.
🚀 Features

    Run LLaMA 2.3 models: Choose between 1 billion or 3 billion parameter models based on your device’s resources.
    Efficient resource usage: Designed for Android devices with minimal resource consumption.
    Easy setup: No complex configuration—just install and start using!
    Interactive UI: Smooth and user-friendly interface for model interaction.
    On-device inference: Fully functional without internet connectivity once models are installed.
    Customizable: Modify settings and preferences directly within the app.

📋 Requirements

    Device specifications:
        RAM: At least 1GB for the 1B model and 2GB for the 3B model.
        CPU: ARM-based or x86 Android devices.
        OS: Android 10.0 or higher.
    Installed tools:
        Termux
        Ollama app (this repository)

📦 Installation

Follow these steps to install and configure Ollama:
1. Install Termux

    Download Termux from F-Droid or its GitHub repository.
2. Set Up Termux

After launching Termux, follow these steps to set up the environment:

    Grant Storage Access:

   termux-setup-storage

This command lets Termux access your Android device’s storage, enabling easier file management.

    Update Packages:

   pkg upgrade

Enter Y when prompted to update Termux and all installed packages.

    Install Essential Tools:

   pkg install git cmake golang

These packages include Git for version control, CMake for building software, and Go, the programming language in which Ollama is written.
3. Install and Compile Ollama

Ollama is a platform for running large models locally. Here’s how to install and set it up:

    Clone Ollama's GitHub Repository:

   git clone --depth 1 https://github.com/ollama/ollama.git

    Navigate to the Ollama Directory:

   cd ollama

    Generate Go Code:

   go generate ./...

    Build Ollama:

   go build .

    Start Ollama Server:

   ./ollama serve &


4. Install the Ollama App

    Download and install the Ollama APK on your device.

🌟 Why Ollama?

Ollama makes running state-of-the-art AI models accessible and efficient for everyone. Whether you're a developer, a student, or just an enthusiast, Ollama provides an easy-to-use platform for interacting with Meta’s advanced large language models—all on your Android device!

🤝 Contribution
We welcome contributions from the community! Feel free to fork this repository, submit issues, or propose enhancements.
📧 Support

presently android and linux only supported

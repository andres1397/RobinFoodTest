#!/bin/bash -v
sudo apt update -y
sudo apt install -y git
sudo apt install -y nodejs
sudo apt install -y npm
sudo mkdir app
cd app
sudo git clone https://github.com/juan-ruiz/movie-analyst-ui.git
cd movie-analyst-ui
sudo npm install
sudo echo "BACK_HOST=192.168.30.10" >> /etc/environment
sudo tmux new-session -d -s "front" node /app/movie-analyst-ui/server.js

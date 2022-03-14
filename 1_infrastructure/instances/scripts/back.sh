#!/bin/bash -v
sudo apt update -y
sudo apt install -y git
sudo apt install -y nodejs
sudo apt install -y npm
sudo mkdir app
cd app
sudo git clone https://github.com/juan-ruiz/movie-analyst-api.git
cd movie-analyst-api
sudo npm install
sudo echo "PORT=3000" >> /etc/environment
sudo tmux new-session -d -s "back" node /app/movie-analyst-api/server.js


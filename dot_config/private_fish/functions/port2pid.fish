function port2pid -a port -d "Show the PIDs occupying a port"
    lsof -t -i tcp:"$port" 
end


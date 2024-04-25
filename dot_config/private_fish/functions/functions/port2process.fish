function port2process -a port -d "Show the processes occupying a port"
  for i in (lsof -t -i tcp:$port)
    ps -efww | awk -v port=$i '$2 == port {print $0}'
  end
end

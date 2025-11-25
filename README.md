docker build -t aigc_agent_server . 

docker run --name aigc_agent_server -p 9000:9000 aigc_agent_server

docker exec -it aigc_agent_server  /bin/bash

docker logs aigc_agent_server
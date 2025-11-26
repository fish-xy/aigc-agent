docker build -t maxxiong001/aigc_agent_server:latest . 

docker run --name aigc_agent_server -p 9000:9000 maxxiong001/aigc_agent_server:latest

docker exec -it aigc_agent_server  /bin/bash

docker logs aigc_agent_server
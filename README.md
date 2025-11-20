docker build -t age-classification-api .

docker run -p 9000:9000 age-classification-api

docker exec -it age-classification-api  /bin/bash

docker logs age-classification-api
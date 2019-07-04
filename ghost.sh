#!/bin/bash

CMD=$1
shift

case $CMD in
    run)
        docker-compose up --build -d
        docker-compose logs -f
        ;;

    setup)
        docker-compose run --rm app perl /app/bin/setup-integration-service.pl
        ;;

    stop)
        docker-compose down --remove-orphans
        ;;

    mysql)
        docker-compose exec db mysql -pawesomepassword
        ;;

    *)
        echo "usage: $0 [run|stop|mysql|setup]"
        exit 1
        ;;
esac

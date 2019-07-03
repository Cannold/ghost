#!/bin/bash

CMD=$1
shift

case $CMD in
    run)
        docker-compose up -d
        docker-compose logs -f
        ;;

    mysql)
        docker-compose exec db mysql -pawesomepassword
        ;;

    *)
        echo "usage: $0 [run|mysql]"
        exit 1
        ;;
esac

# ghost

## How to run the stack
1. `./ghost.sh run` to initiate docker compose stack
2. `./ghost.sh setup` to setup secret and ID for both Admin and Content API

Frontend access is at port http://localhost:8080/

To access admin side, you can go to http://localhost:8080/ghost with following login details
- Email: test01@mail.com
- Password: long_pass_01

## Populating data
`./bin/post-to-ghost.sh`

This script will make a POST request via Admin API for each post in `data/backup.yml`. When the content is sent to the server successfully, they can be viewed it in its MySQL database. Ghost doesn't store these content locally. 

Note: at the moment, all posts and pages that are imported from `bin/backup.yml` will be have their published status as  **draft**. 

## Access database
`./ghost.sh mysql`


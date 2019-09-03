const GhostAdminAPI = require('@tryghost/admin-api');
const util = require('util');

const api = new GhostAdminAPI({
  url: 'https://lesliecannold.ghost.io',
  key: '{A}:{B}',
  version: 'v2'
});

api.posts.browse({
    limit: 'all',
    filter: 'status:draft'
})
.then((posts) => {
    posts.forEach((post) => {
        console.log(post.title);
        api.posts.edit({id: post.id, status: 'published', updated_at: post.updated_at});
    });
})
.catch((err) => {
    console.error(err);
});

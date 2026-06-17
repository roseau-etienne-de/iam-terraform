{
    "client_n": {
        "project_lvl_roles": [ 
            "projects/${project_id}/roles/CustomBucketRole"
        ],
        "buckets": [ "bucket-client-n" ],
        "members": [
            "user:zelda@client_n.com",
            "user:link@client_n.com"
        ]
    },

    "analytics360-bigquery-supports": {
        "project_lvl_roles": [
            "projects/${project_id}/roles/CustomBigQueryRole"
        ],
        "datasets": [ "dataset_1" ],
        "members": [
            "group:analytics360-bigquery-supports@google.com"
        ]
    },

    "client_z": {
        "project_lvl_roles": [
            "projects/${project_id}/roles/CustomBucketRole",
            "projects/${project_id}/roles/CustomBigQueryRole"
        ],
        "buckets": [
            "bucket-1"
            "bucket-2"
        ],
        "datasets": [
            "dataset_1",
            "dataset_2"
        ],
        "members": [
            "tyler@z.com",
            "edward@z.com"
            "marta@z.com
        ]
    },
}

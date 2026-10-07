apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: benchmark
  namespace: vector-search-local
  labels:
    app.kubernetes.io/part-of: vector-search-platform-benchmark
spec:
  version: __ELASTICSEARCH_VERSION__
  nodeSets:
    - name: default
      count: 1
      config:
        node.store.allow_mmap: false
        node.roles:
          - master
          - data
          - data_content
          - data_hot
          - ingest
          - remote_cluster_client
      podTemplate:
        spec:
          containers:
            - name: elasticsearch
              resources:
                requests:
                  cpu: 500m
                  memory: 1Gi
                limits:
                  cpu: "2"
                  memory: 2Gi
      volumeClaimTemplates:
        - metadata:
            name: elasticsearch-data
          spec:
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 5Gi
            storageClassName: standard


#!/usr/bin/python3
import yaml, json, sys

file_path = sys.argv[1]
num_nodes = int(sys.argv[2])
node_affinity_num = int(sys.argv[3])
node_affinity_name = "node-" + str(node_affinity_num)
anti_affinity_node_arr = ["node-none"]

# if (node_affinity_num > num_nodes):
#   node_id = (node_affinity_num - ( num_nodes * ( node_affinity_num//num_nodes )))
#   if (node_id != 0):
#     node_affinity_num = node_id
#   else:
#     node_affinity_num = num_nodes

node_affinity_name = "node-" + str(node_affinity_num)

for i in range(1, num_nodes + 1):
    if i != node_affinity_num:
        anti_affinity_node_arr.append("node-" + str(i))

if num_nodes == 1:
    anti_affinity_node_arr.append("node-none")

node_affinity = {
    "nodeAffinity": {
        "preferredDuringSchedulingIgnoredDuringExecution": [
            {
                "weight": 100,
                "preference": {
                    "matchExpressions": [
                        {
                            "key": "instance",
                            "operator": "In",
                            "values": [node_affinity_name],
                        }
                    ]
                },
            }
        ]
    }
}

pod_affinity = {
    "podAffinity": {
        "preferredDuringSchedulingIgnoredDuringExecution": [
            {
                "weight": 100,
                "podAffinityTerm": {
                    "labelSelector": {
                        "matchExpressions": [
                            {
                                "key": "instance",
                                "operator": "In",
                                "values": [node_affinity_name],
                            }
                        ]
                    },
                    "topologyKey": "kubernetes.io/hostname",
                },
            }
        ]
    }
}

pod_anti_affinity = {
    "podAntiAffinity": {
        "preferredDuringSchedulingIgnoredDuringExecution": [
            {
                "weight": 100,
                "podAffinityTerm": {
                    "labelSelector": {
                        "matchExpressions": [
                            {"key": "instance", "operator": "In", "values": {""},}
                        ]
                    },
                    "topologyKey": "kubernetes.io/hostname",
                },
            }
        ]
    }
}

pod_anti_affinity["podAntiAffinity"]["preferredDuringSchedulingIgnoredDuringExecution"][
    0
]["podAffinityTerm"]["labelSelector"]["matchExpressions"][0][
    "values"
] = anti_affinity_node_arr

print("Reading file for updation", file_path)
file_read = open(file_path, "r")
kubeobject = json.loads(json.dumps(yaml.load(file_read.read(), Loader=yaml.FullLoader)))
try:
    y = kubeobject["spec"]["template"]["metadata"]["labels"]["instance"]
    kubeobject["spec"]["template"]["metadata"]["labels"][
        "instance"
    ] = node_affinity_name
except KeyError:
    pass

try:
    x = kubeobject["spec"]["template"]["spec"]["affinity"]
    print("key already exist")
    print(kubeobject["spec"]["template"]["spec"]["affinity"].keys())
    kubeobject["spec"]["template"]["spec"]["affinity"]["podAffinity"][
        "preferredDuringSchedulingIgnoredDuringExecution"
    ] = pod_affinity["podAffinity"]["preferredDuringSchedulingIgnoredDuringExecution"]
    kubeobject["spec"]["template"]["spec"]["affinity"] = {
        **node_affinity,
        **kubeobject["spec"]["template"]["spec"]["affinity"],
        **pod_anti_affinity,
    }
except KeyError:
    kubeobject["spec"]["template"]["spec"]["affinity"] = {
        **node_affinity,
        **pod_affinity,
        **pod_anti_affinity,
    }

# print(yaml.dump(kubeobject, indent=1, default_flow_style=False))
# sys.exit()
file_write = open(file_path, "w")
file_write.write(yaml.dump(kubeobject, default_flow_style=False))
print("Sucessfully completed adding labels", file_path)


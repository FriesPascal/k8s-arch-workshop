locals {
  # Helper for outputs
  yaml = "---\n${yamlencode(lookup(local.merge_lvl_0, "", {}))}...\n"

  #
  # Recursively parse input maps as anchored key-value lists
  #
  parse_lvl_0 = concat([], [for i in var.from_yaml :
    [for k, v in yamldecode(i) :
      {
        parent       = ""
        key          = k
        value        = v
        has_children = can(merge(v, {})) && v != null
      }
    ]
  ]...)
  parse_lvl_1 = concat([], [for i in local.parse_lvl_0 :
    [for k, v in i.value :
      {
        parent       = "${i.parent}.\"${i.key}\""
        key          = k
        value        = v
        has_children = can(merge(v, {})) && v != null
      }
    ] if i.has_children
  ]...)
  parse_lvl_2 = concat([], [for i in local.parse_lvl_1 :
    [for k, v in i.value :
      {
        parent       = "${i.parent}.\"${i.key}\""
        key          = k
        value        = v
        has_children = can(merge(v, {})) && v != null
      }
    ] if i.has_children
  ]...)
  parse_lvl_3 = concat([], [for i in local.parse_lvl_2 :
    [for k, v in i.value :
      {
        parent       = "${i.parent}.\"${i.key}\""
        key          = k
        value        = v
        has_children = can(merge(v, {})) && v != null
      }
    ] if i.has_children
  ]...)
  parse_lvl_4 = concat([], [for i in local.parse_lvl_3 :
    [for k, v in i.value :
      {
        parent       = "${i.parent}.\"${i.key}\""
        key          = k
        value        = v
        has_children = can(merge(v, {})) && v != null
      }
    ] if i.has_children
  ]...)
  parse_lvl_5 = concat([], [for i in local.parse_lvl_4 :
    [for k, v in i.value :
      {
        parent       = "${i.parent}.\"${i.key}\""
        key          = k
        value        = v
        has_children = can(merge(v, {})) && v != null
      }
    ] if i.has_children
  ]...)
  parse_lvl_6 = concat([], [for i in local.parse_lvl_5 :
    [for k, v in i.value :
      {
        parent       = "${i.parent}.\"${i.key}\""
        key          = k
        value        = v
        has_children = can(merge(v, {})) && v != null
      }
    ] if i.has_children
  ]...)
  parse_lvl_7 = concat([], [for i in local.parse_lvl_6 :
    [for k, v in i.value :
      {
        parent       = "${i.parent}.\"${i.key}\""
        key          = k
        value        = v
        has_children = can(merge(v, {})) && v != null
      }
    ] if i.has_children
  ]...)
  parse_lvl_8 = concat([], [for i in local.parse_lvl_7 :
    [for k, v in i.value :
      {
        parent       = "${i.parent}.\"${i.key}\""
        key          = k
        value        = v
        has_children = can(merge(v, {})) && v != null
      }
    ] if i.has_children
  ]...)
  parse_lvl_9 = concat([], [for i in local.parse_lvl_8 :
    [for k, v in i.value :
      {
        parent       = "${i.parent}.\"${i.key}\""
        key          = k
        value        = v
        has_children = can(merge(v, {})) && v != null
      }
    ] if i.has_children
  ]...)
  parse_lvl_10 = concat([], [for i in local.parse_lvl_9 :
    [for k, v in i.value :
      {
        parent       = "${i.parent}.\"${i.key}\""
        key          = k
        value        = v
        has_children = can(merge(v, {})) && v != null
      }
    ] if i.has_children
  ]...)


  #
  # Merge parsed lists back to one big map.
  # Note that the `jsonencode / jsondecode` implements
  # lazy type checking for Terraform.
  #
  merge_lvl_10 = {
    for k, v in { for i in local.parse_lvl_10 :
      i.parent => {
        key   = i.key
        value = i.value
      }...
    } : k => zipmap(v[*].key, v[*].value)
  }
  merge_lvl_9 = {
    for k, v in { for i in local.parse_lvl_9 :
      i.parent => {
        key   = i.key
        value = jsondecode(i.has_children ? jsonencode(local.merge_lvl_10["${i.parent}.\"${i.key}\""]) : jsonencode(i.value))
      }...
    } : k => zipmap(v[*].key, v[*].value)
  }
  merge_lvl_8 = {
    for k, v in { for i in local.parse_lvl_8 :
      i.parent => {
        key   = i.key
        value = jsondecode(i.has_children ? jsonencode(local.merge_lvl_9["${i.parent}.\"${i.key}\""]) : jsonencode(i.value))
      }...
    } : k => zipmap(v[*].key, v[*].value)
  }
  merge_lvl_7 = {
    for k, v in { for i in local.parse_lvl_7 :
      i.parent => {
        key   = i.key
        value = jsondecode(i.has_children ? jsonencode(local.merge_lvl_8["${i.parent}.\"${i.key}\""]) : jsonencode(i.value))
      }...
    } : k => zipmap(v[*].key, v[*].value)
  }
  merge_lvl_6 = {
    for k, v in { for i in local.parse_lvl_6 :
      i.parent => {
        key   = i.key
        value = jsondecode(i.has_children ? jsonencode(local.merge_lvl_7["${i.parent}.\"${i.key}\""]) : jsonencode(i.value))
      }...
    } : k => zipmap(v[*].key, v[*].value)
  }
  merge_lvl_5 = {
    for k, v in { for i in local.parse_lvl_5 :
      i.parent => {
        key   = i.key
        value = jsondecode(i.has_children ? jsonencode(local.merge_lvl_6["${i.parent}.\"${i.key}\""]) : jsonencode(i.value))
      }...
    } : k => zipmap(v[*].key, v[*].value)
  }
  merge_lvl_4 = {
    for k, v in { for i in local.parse_lvl_4 :
      i.parent => {
        key   = i.key
        value = jsondecode(i.has_children ? jsonencode(local.merge_lvl_5["${i.parent}.\"${i.key}\""]) : jsonencode(i.value))
      }...
    } : k => zipmap(v[*].key, v[*].value)
  }
  merge_lvl_3 = {
    for k, v in { for i in local.parse_lvl_3 :
      i.parent => {
        key   = i.key
        value = jsondecode(i.has_children ? jsonencode(local.merge_lvl_4["${i.parent}.\"${i.key}\""]) : jsonencode(i.value))
      }...
    } : k => zipmap(v[*].key, v[*].value)
  }
  merge_lvl_2 = {
    for k, v in { for i in local.parse_lvl_2 :
      i.parent => {
        key   = i.key
        value = jsondecode(i.has_children ? jsonencode(local.merge_lvl_3["${i.parent}.\"${i.key}\""]) : jsonencode(i.value))
      }...
    } : k => zipmap(v[*].key, v[*].value)
  }
  merge_lvl_1 = {
    for k, v in { for i in local.parse_lvl_1 :
      i.parent => {
        key   = i.key
        value = jsondecode(i.has_children ? jsonencode(local.merge_lvl_2["${i.parent}.\"${i.key}\""]) : jsonencode(i.value))
      }...
    } : k => zipmap(v[*].key, v[*].value)
  }
  merge_lvl_0 = {
    for k, v in { for i in local.parse_lvl_0 :
      i.parent => {
        key   = i.key
        value = jsondecode(i.has_children ? jsonencode(local.merge_lvl_1["${i.parent}.\"${i.key}\""]) : jsonencode(i.value))
      }...
    } : k => zipmap(v[*].key, v[*].value)
  }
}

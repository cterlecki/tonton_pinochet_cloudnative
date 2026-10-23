collaborators = {
  Djangss   = "push"
  TomOplomo = "push"
  Kloox     = "push" # instructor
}

prd_reviewers = ["cterlecki", "Djangss", "TomOplomo"]

release_actors = ["cterlecki", "Djangss", "TomOplomo"]

# Dev scale set (infra/foundation output runner_label). Set to "" to fall back to ubuntu-latest.
runner_label = "tonton-pinochet-cloudnative-dev"

deployer_role_arns = {
  dev = "arn:aws:iam::807944327030:role/github-deployer"
  prd = "arn:aws:iam::255530396603:role/github-deployer"
}

required_status_checks = [
  "source-is-dev",
  "validate",
  "plan (foundation, dev)",
  "plan (foundation, prd)",
  "plan (serverless, dev)",
  "plan (serverless, prd)",
]

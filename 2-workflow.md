# Argo Workflow
_https://argoproj.github.io/argo-workflows/workflow-concepts/_

[TOC]

The Workflow is the most important resource in Argo and serves two important functions:
* It defines the workflow to be executed.
* It stores the state of the workflow.
  
A typical workflow spec contains following:
* Kubernetes header including meta-data
* Spec body
    * Entrypoint invocation with optional arguments
    * List of template definitions
*For each template definition
    * Name of the template
    * Optionally a list of inputs
    * Optionally a list of outputs
    * Container invocation (leaf template) or a list of steps
        *   For each step, a template invocation

```yaml
#### simple workflow
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: hello
spec:
  serviceAccountName: argo # this is the service account that the workflow will run with
  entrypoint: main # the first template to run in the workflows
  templates:
  - name: main
    container: # this is a container template
      image: docker/whalesay # this image prints "hello world" to the console
      command: ["cowsay"]
```
Make sure to include or specify serviceAccountName to submit a argoworkflow job.
For eg:
`argo submit -n argo --serviceaccount argo --watch https://raw.githubusercontent.com/argoproj/argo-workflows/master/examples/hello-world.yaml`

## To view workflow via argoCLI
```bash
argo list -n argo
argo list -n argo @latest ## to provide the details for the last/latest workflow
```
# Templates
They define the instructions to be executed with the first starting point being "entrypoint" (_main function_).
There are 6 types of templates organized under 2 categories.
1. WORK
2. ORCHESTRATION

## WORK
Defines "work" to be done.

a. Container : reserves a container. Just like you define a docker conatiner in kubernetes. Most common template type.
```yaml
templates:
  - name: main
    container:
      image: docker/whalesay
      command: [cowsay]
      args: ["hello world"]
```
b. Container Set: A container set allows you to run multiple containers in a single pod.
c. Script: A script template allows you to run a script in a container. The spec is the same as a container, but adds the source: field which allows you to define a script in-place.
```yaml
  - name: gen-random-int
    script:
      image: python:alpine3.6
      command: [python]
      source: |
        import random
        i = random.randint(1, 100)
        print(i)
```

d. Data: A data template allows you get data from storage
e. Resource: A resource template allows you to create a Kubernetes resource and wait for it to meet a condition (e.g. successful) 

## ORCHESTRATION
The second category orchestrates the work:
a. Steps: A steps template allows you to run a series of steps in sequence. Its a list of lists 
b. DAG: A DAG template is a common type of orchestration template. It allows task dependencies that is reflected as a "graph". 
c. Suspend: A suspend template allows you to automatically suspend a workflow, e.g. while waiting on manual approval, or while an external system does some work.

Orchestration templates do NOT run pods. You can check by running kubectl get pods.

All templates run as pod thus can be viewed by using kubectl commands

`kubectl get pods -l workflows.argoproj.io/workflow`

## WORKFLOW TEMPLATES
Similar to pipelines in jenkins, allows you to create a library of frequently used templates and reuse them either by submitting them directly or referencing them in the workflow.

A WorkflowTemplate is a definition of a Workflow that lives in your cluster, which also contains templates. This templates can be referenced from within WFT and from other workflows and WFTs on the cluster.
```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: hello
spec:
  entrypoint: main
  templates:
    - name: main
      container:
        image: docker/whalesay
        command: [cowsay]
```
> **Difference between a template in a Workflow and WorkflowTemplates:**
>   A template (lower-case) is a task within a Workflow. Whenever you define a Workflow, you must define at least one (but usually more than one) template to run. This template can be of type container, script, dag, steps, resource, or suspend and can be referenced by an entrypoint or by other dag, and step templates.

You can reference templates from another WorkflowTemplates using a templateRef field.

### Steps and DAG
A step is a multi-step workflow which can run in paralled or one after the other. A step can reference a template.

```yaml

apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: steps-
spec:
  entrypoint: hello-hello-hello

  # This spec contains two templates: hello-hello-hello and whalesay
  templates:
 —name: hello-hello-hello
    # Instead of just running a container
    # This template has a sequence of steps
    steps:
   —- name: hello1            # hello1 is run before the following steps
        template: whalesay
        arguments:
          parameters:
         —name: message
            value: "hello1"
   —- name: hello2a           # double dash => run after previous step
        template: whalesay
        arguments:
          parameters:
         —name: message
            value: "hello2a"
     —name: hello2b           # single dash => run in parallel with previous step
        template: whalesay
        arguments:
          parameters:
         —name: message
            value: "hello2b"

  # This is the same template as from the previous example
 —name: whalesay
    inputs:
      parameters:
     —name: message
    container:
      image: docker/whalesay
      command: [cowsay]
      args: ["{{inputs.parameters.message}}"]
```
>spec:arguments:parameters field specifies a parameter that can be passed to the templates below.
>Note that parameters must be enclosed in double quotes to escape the curly braces, like this: "{{inputs.parameters.message}}

Parameters can be over-ridden using argo cli.
`argo submit arguments-parameters.yaml -p message="goodbye world"`
Similary entrypoint can also be overridden (provided template exists):
`argo submit arguments-parameters.yaml --entrypoint whalesay-caps`

A DAG (Direct-acrylic graph) specifies dependencies of each task, making it simpler to maintain complex workflows.
```yaml
dag-workflow.yaml 
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: dag-
spec:
  entrypoint: main # main template for the DAG
  templates:
    - name: main
      dag:
        tasks: #dag has 2 tasks defined a and b
          - name: a
            template: whalesay #uses whalesay template which is same as container template
          - name: b
            template: whalesay
            dependencies:
              - a # b wont start until a is complted
    - name: whalesay
      container:
        image: docker/whalesay
        command: [cowsay]
        args: ["hello world"]
```
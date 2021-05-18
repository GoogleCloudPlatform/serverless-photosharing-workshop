# Terraform

You can setup each lab using Terraform. It's assumed that you setup each lab in
progression (Lab 1 followed by Lab 2, etc.).

Run the following commands inside each lab folder.

1. If there's a `build.sh` file in the folder, run that first to build the
   required containers:

    ```sh
    ./build.sh
    ```

1. Initialize terraform:

    ```sh
    terraform init
    ```

1. See the planned changes:

    ```sh
    terraform plan -var="project_id=YOUR-PROJECT-ID"
    ```

1. Create resources:

    ```sh
    terraform apply -var="project_id=YOUR-PROJECT-ID"
    ```

1. (Optional) If you want to destroy the deleted resources later:

    ```sh
    terraform destry -var="project_id=YOUR-PROJECT-ID"
    ```

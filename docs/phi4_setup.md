# Setting up phi4-mini for Reliable Function Calling

## Introduction

Microsoft's `phi4-mini` language model has shown promise for function calling tasks. However, to ensure reliable and consistent behavior, especially for its `functools` style output, it's recommended to use a custom Ollama Modelfile. This setup configures the model's template to explicitly guide its output format for tool calls.

This guide will walk you through creating a custom Modelfile for `phi4-mini` and making it available in Ollama.

## Detailed Steps

### 1. Create the Modelfile

You'll need to create a new file named `phi4_fc_ollama.Modelfile` (or any other name, but be consistent). This file defines how Ollama should serve the `phi4-mini` model, including a custom template for function calling.

**Modelfile Content:**

```modelfile
FROM phi4-mini:latest
# Note: If your base model is named differently (e.g., after a specific download),
# change 'phi4-mini:latest' to match the name you see in 'ollama list'.

# Template for phi4-mini to encourage functools format
TEMPLATE """<|user|>
{{ .Prompt }}<|end|>
<|assistant|>
{{if .ToolCalls }}functools[{{ range $idx, $tool := .ToolCalls }}
 {
  "name": "{{$tool.Function.Name}}",
  "arguments": {{$tool.Function.Arguments}}
 }{{end}}
]{{else}}{{ .Response }}{{end}}<|end|>
"""

SYSTEM """You are a helpful AI assistant.
You have access to the following tools:
{{ range .Tools }}
<tool_name>
{{ .Name }}
</tool_name>
<tool_description>
{{ .Description }}
</tool_description>
<tool_parameters>
{{ .Parameters }}
</tool_parameters>
{{ end }}
When you need to use a tool, respond with a JSON object in the following format inside `functools[...]`:
`functools[{"name": "<tool_name>", "arguments": {"<param_name>": "<param_value>"}}]`
If you need to use multiple tools, include them in the list:
`functools[{"name": "<tool_name_1>", "arguments": {...}}, {"name": "<tool_name_2>", "arguments": {...}}]`
Only respond with the `functools[...]` structure if a tool is being called. Do not add any other text before or after it.
If no tool is needed, respond with a regular text message.
"""

# Recommended Parameters (adjust as needed)
PARAMETER stop "<|end|>"
PARAMETER stop "<|user|>"
PARAMETER stop "<|assistant|>"
PARAMETER stop "functools["
```

**Creating the file:**

You can create this file using any text editor. Alternatively, you can use command-line methods:

*   **PowerShell:**
    ```powershell
    $modelfileContent = @"
    FROM phi4-mini:latest
    # Note: If your base model is named differently (e.g., after a specific download),
    # change 'phi4-mini:latest' to match the name you see in 'ollama list'.

    # Template for phi4-mini to encourage functools format
    TEMPLATE """<|user|>
    {{ .Prompt }}<|end|>
    <|assistant|>
    {{if .ToolCalls }}functools[{{ range $idx, $tool := .ToolCalls }}
     {
      "name": "{{$tool.Function.Name}}",
      "arguments": {{$tool.Function.Arguments}}
     }{{end}}
    ]{{else}}{{ .Response }}{{end}}<|end|>
    """

    SYSTEM """You are a helpful AI assistant.
    You have access to the following tools:
    {{ range .Tools }}
    <tool_name>
    {{ .Name }}
    </tool_name>
    <tool_description>
    {{ .Description }}
    </tool_description>
    <tool_parameters>
    {{ .Parameters }}
    </tool_parameters>
    {{ end }}
    When you need to use a tool, respond with a JSON object in the following format inside `functools[...]`:
    `functools[{"name": "<tool_name>", "arguments": {"<param_name>": "<param_value>"}}]`
    If you need to use multiple tools, include them in the list:
    `functools[{"name": "<tool_name_1>", "arguments": {...}}, {"name": "<tool_name_2>", "arguments": {...}}]`
    Only respond with the `functools[...]` structure if a tool is being called. Do not add any other text before or after it.
    If no tool is needed, respond with a regular text message.
    """

    # Recommended Parameters (adjust as needed)
    PARAMETER stop "<|end|>"
    PARAMETER stop "<|user|>"
    PARAMETER stop "<|assistant|>"
    PARAMETER stop "functools["
    "@
    Set-Content -Path "./phi4_fc_ollama.Modelfile" -Value $modelfileContent
    ```

*   **Bash (Linux/macOS/WSL):**
    ```bash
    cat << EOF > ./phi4_fc_ollama.Modelfile
    FROM phi4-mini:latest
    # Note: If your base model is named differently (e.g., after a specific download),
    # change 'phi4-mini:latest' to match the name you see in 'ollama list'.

    # Template for phi4-mini to encourage functools format
    TEMPLATE """<|user|>
    {{ .Prompt }}<|end|>
    <|assistant|>
    {{if .ToolCalls }}functools[{{ range $idx, $tool := .ToolCalls }}
     {
      "name": "{{$tool.Function.Name}}",
      "arguments": {{$tool.Function.Arguments}}
     }{{end}}
    ]{{else}}{{ .Response }}{{end}}<|end|>
    """

    SYSTEM """You are a helpful AI assistant.
    You have access to the following tools:
    {{ range .Tools }}
    <tool_name>
    {{ .Name }}
    </tool_name>
    <tool_description>
    {{ .Description }}
    </tool_description>
    <tool_parameters>
    {{ .Parameters }}
    </tool_parameters>
    {{ end }}
    When you need to use a tool, respond with a JSON object in the following format inside `functools[...]`:
    `functools[{"name": "<tool_name>", "arguments": {"<param_name>": "<param_value>"}}]`
    If you need to use multiple tools, include them in the list:
    `functools[{"name": "<tool_name_1>", "arguments": {...}}, {"name": "<tool_name_2>", "arguments": {...}}]`
    Only respond with the `functools[...]` structure if a tool is being called. Do not add any other text before or after it.
    If no tool is needed, respond with a regular text message.
    """

    # Recommended Parameters (adjust as needed)
    PARAMETER stop "<|end|>"
    PARAMETER stop "<|user|>"
    PARAMETER stop "<|assistant|>"
    PARAMETER stop "functools["
    EOF
    ```

### 2. Create the Custom Ollama Model

Once the Modelfile is created, open your terminal and run the `ollama create` command. This command packages your model with the custom settings.

*   **Replace `<path_to_modelfile>` with the actual path to your `phi4_fc_ollama.Modelfile`**.
    *   If it's in the current directory, you can use `./phi4_fc_ollama.Modelfile` (for PowerShell/bash) or `phi4_fc_ollama.Modelfile` (for cmd).

*   **PowerShell:**
    ```powershell
    ollama create phi4-mini-functools -f ./phi4_fc_ollama.Modelfile
    ```

*   **Command Prompt (cmd):**
    ```cmd
    ollama create phi4-mini-functools -f phi4_fc_ollama.Modelfile
    ```

*   **Bash (Linux/macOS/WSL):**
    ```bash
    ollama create phi4-mini-functools -f ./phi4_fc_ollama.Modelfile
    ```

This command might take a few moments to complete. Ollama will import the base model (if not already present) and apply your custom template and parameters.

### 3. Using the Custom Model with the Agent

After the `ollama create` command succeeds, you will have a new model named `phi4-mini-functools` (or whatever you named it) available in Ollama.

To use this with your agent (e.g., the Roblox Studio AI Broker):
1.  Update your agent's configuration (e.g., `config.json` or command-line arguments) to specify `phi4-mini-functools` as the Ollama model name.
    *   For example, if using command-line arguments: `--ollama_model phi4-mini-functools`
2.  Relaunch your agent. It should now use the customized `phi4-mini` model, which is better suited for function calling.

## Troubleshooting

*   **`ollama create` fails:**
    *   Double-check the path to your Modelfile.
    *   Ensure the `FROM` line in your Modelfile correctly references a `phi4-mini` base model that you have pulled or is available (e.g., `phi4-mini:latest`). You can see your available models with `ollama list`.
    *   Inspect the Ollama server logs for more detailed error messages. The location of these logs can vary by operating system.
*   **Model doesn't use `functools`:**
    *   Verify that the `phi4-mini-functools` model is actually being used by your agent.
    *   Ensure the `TEMPLATE` and `SYSTEM` prompts in your Modelfile were copied exactly as provided. Even small deviations can affect behavior.
    *   The `PARAMETER stop "functools["` line is important to help the model stop generating after starting the functools block, but other factors in the prompt also guide it.

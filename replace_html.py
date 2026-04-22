import re

with open('ReadXR/ReaderView.swift', 'r') as f:
    content = f.read()

pattern = re.compile(r'    private func buildHTML\(_ content: String\) -> String \{.*?        """\n    \}\n\}', re.DOTALL)

new_text = """    private func buildHTML(_ content: String) -> String {
        let userSelectValue = isExternalDisplayConnected ? "none" : "text"
        
        let cssPath = Bundle.main.path(forResource: "ReaderStyles", ofType: "css")
        let jsPath = Bundle.main.path(forResource: "ReaderScripts", ofType: "js")
        
        let css = (try? String(contentsOfFile: cssPath ?? "")) ?? ""
        let js = (try? String(contentsOfFile: jsPath ?? "")) ?? ""

        return \"\"\"
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
            :root {
                --user-font-size: \\(fontSize)em;
                --user-font-color: \\(fontColor);
                --user-justify: \\(justify);
                --raw-margin: \\(margin);
                --user-tb-margin: \\(Int(topBottomMargin * 100))vh;
                --user-margin-px: 0px;
                --user-gap-px: 0px;
            }
            \\(css)
            body {
                -webkit-user-select: \\(userSelectValue);
                user-select: \\(userSelectValue);
            }
            </style>
            <script>
            \\(js)
            </script>
        </head>
        <body>\\(content)</body>
        </html>
        \"\"\"
    }
}"""

if pattern.search(content):
    content = pattern.sub(new_text, content)
    with open('ReadXR/ReaderView.swift', 'w') as f:
        f.write(content)
    print("Replacement successful")
else:
    print("Pattern not found")

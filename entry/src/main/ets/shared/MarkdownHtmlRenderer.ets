const RAWFILE_BASE: string = 'resource://rawfile/markdown/';

export function buildMarkdownHtml(markdown: string, fontSize: number): string {
  const source: string = toScriptString(normalizeTaskListMarkers(markdown));
  const bodyFontSize: number = clampFontSize(fontSize);
  const codeFontSize: number = Math.max(bodyFontSize - 1, 12);
  return '<!DOCTYPE html>' +
    '<html><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">' +
    '<link rel="stylesheet" href="' + RAWFILE_BASE + 'katex.min.css">' +
    '<style>' + buildRendererCss(bodyFontSize, codeFontSize) + '</style>' +
    '</head><body><article id="content" class="markdown-body"></article>' +
    '<script src="' + RAWFILE_BASE + 'markdown-it.min.js"></script>' +
    '<script src="' + RAWFILE_BASE + 'katex.min.js"></script>' +
    '<script src="' + RAWFILE_BASE + 'auto-render.min.js"></script>' +
    '<script>' + buildRendererScript(source) + '</script>' +
    '</body></html>';
}

export function estimateMarkdownHeight(markdown: string, fontSize: number): number {
  const normalized: string = markdown.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  const lines: string[] = normalized.split('\n');
  const lineHeight: number = Math.max(fontSize + 8, 22);
  let visualLines: number = 1;
  let inCodeBlock: boolean = false;

  for (let i = 0; i < lines.length; i++) {
    const line: string = lines[i];
    const trimmed: string = line.trim();
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      inCodeBlock = !inCodeBlock;
      visualLines += 1;
      continue;
    }
    if (trimmed.length === 0) {
      visualLines += 0.55;
      continue;
    }
    if (inCodeBlock) {
      visualLines += 1.15;
      continue;
    }
    if (trimmed.indexOf('|') >= 0) {
      visualLines += 1.35;
      continue;
    }
    if (trimmed.startsWith('$$') || trimmed.startsWith('\\[')) {
      visualLines += 2.2;
      continue;
    }
    visualLines += Math.max(1, Math.ceil(trimmed.length / 34));
  }

  return Math.min(Math.max(Math.ceil(visualLines * lineHeight + 28), 48), 4200);
}

export function normalizeTaskListMarkers(markdown: string): string {
  const lines: string[] = markdown.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
  const normalized: string[] = [];
  for (let i = 0; i < lines.length; i++) {
    let line: string = lines[i];
    line = replaceTaskMarker(line, '- [ ] ', '- ☐ ');
    line = replaceTaskMarker(line, '* [ ] ', '* ☐ ');
    line = replaceTaskMarker(line, '+ [ ] ', '+ ☐ ');
    line = replaceTaskMarker(line, '- [x] ', '- ☑ ');
    line = replaceTaskMarker(line, '* [x] ', '* ☑ ');
    line = replaceTaskMarker(line, '+ [x] ', '+ ☑ ');
    line = replaceTaskMarker(line, '- [X] ', '- ☑ ');
    line = replaceTaskMarker(line, '* [X] ', '* ☑ ');
    line = replaceTaskMarker(line, '+ [X] ', '+ ☑ ');
    normalized.push(line);
  }
  return normalized.join('\n');
}

export function toScriptString(value: string): string {
  const json: string = JSON.stringify(value);
  return json.replace(/<\/script/gi, '<\\/script');
}

function replaceTaskMarker(line: string, marker: string, replacement: string): string {
  const trimmedStart: string = line.trimStart();
  if (!trimmedStart.startsWith(marker)) {
    return line;
  }
  const indentLength: number = line.length - trimmedStart.length;
  return line.substring(0, indentLength) + replacement + trimmedStart.substring(marker.length);
}

function clampFontSize(fontSize: number): number {
  if (fontSize < 12) {
    return 12;
  }
  if (fontSize > 22) {
    return 22;
  }
  return fontSize;
}

function buildRendererCss(fontSize: number, codeFontSize: number): string {
  return ':root{color-scheme:light dark;--bg:transparent;--text:#111;--muted:#737373;--border:#e5e5e5;--code:#fafafa;--link:#2563eb;}' +
    '@media (prefers-color-scheme:dark){:root{--text:#ededed;--muted:#b0b0b0;--border:#262626;--code:#090909;--link:#93c5fd;}}' +
    'html,body{margin:0;padding:0;background:transparent;color:var(--text);font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;font-size:' + fontSize + 'px;line-height:1.55;}' +
    '.markdown-body{box-sizing:border-box;width:100%;overflow-wrap:anywhere;word-break:break-word;}' +
    '.markdown-body>*:first-child{margin-top:0}.markdown-body>*:last-child{margin-bottom:0}' +
    'p{margin:0 0 10px}h1,h2,h3,h4,h5,h6{margin:16px 0 8px;line-height:1.25;font-weight:650}h1{font-size:1.35em}h2{font-size:1.2em}h3{font-size:1.1em}' +
    'ul,ol{margin:0 0 10px 1.25em;padding:0}li{margin:3px 0}li>p{margin:3px 0}' +
    'blockquote{margin:8px 0 10px;padding:2px 0 2px 12px;border-left:3px solid var(--border);color:var(--muted)}' +
    'a{color:var(--link);text-decoration:none}a:active{text-decoration:underline}' +
    'hr{border:0;border-top:1px solid var(--border);margin:14px 0}' +
    'table{display:block;width:100%;max-width:100%;overflow-x:auto;border-collapse:collapse;margin:8px 0 12px;font-size:.95em}' +
    'th,td{border:1px solid var(--border);padding:7px 9px;text-align:left;vertical-align:top}th{font-weight:650;background:color-mix(in srgb,var(--code),transparent 18%)}' +
    'code{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:' + codeFontSize + 'px;background:var(--code);border-radius:4px;padding:1px 4px}' +
    'pre code{background:transparent;border-radius:0;padding:0;font-size:' + codeFontSize + 'px;white-space:pre;word-break:normal;overflow-wrap:normal}' +
    '.code-block{margin:10px 0 12px;background:var(--code);border-radius:8px;overflow:hidden;border:1px solid var(--border)}' +
    '.code-head{display:flex;align-items:center;gap:8px;min-height:34px;padding:0 10px;border-bottom:1px solid var(--border);color:var(--muted);font-size:12px}' +
    '.code-lang{flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.copy-code{border:0;background:transparent;color:var(--muted);font:inherit;padding:6px 2px}' +
    'pre{margin:0;padding:12px;overflow:auto;-webkit-overflow-scrolling:touch}' +
    '.katex-display{overflow-x:auto;overflow-y:hidden;padding:4px 0;margin:10px 0}.katex{font-size:1.04em}.katex-error{color:#b91c1c}' +
    'img{max-width:100%;height:auto;border-radius:6px}';
}

function buildRendererScript(source: string): string {
  return '(function(){' +
    'var source=' + source + ';' +
    'function initMarkdown(){var md=window.markdownit({html:false,linkify:true,typographer:true,breaks:true});' +
    'var defaultLink=md.renderer.rules.link_open||function(tokens,idx,options,env,self){return self.renderToken(tokens,idx,options);};' +
    'md.renderer.rules.link_open=function(tokens,idx,options,env,self){var token=tokens[idx];var target=token.attrIndex("target");if(target<0){token.attrPush(["target","_blank"]);}else{token.attrs[target][1]="_blank";}var rel=token.attrIndex("rel");if(rel<0){token.attrPush(["rel","noopener noreferrer"]);}else{token.attrs[rel][1]="noopener noreferrer";}return defaultLink(tokens,idx,options,env,self);};' +
    'md.renderer.rules.fence=function(tokens,idx){var token=tokens[idx];var info=token.info?md.utils.escapeHtml(token.info.trim().split(/\\s+/g)[0]):"text";var code=md.utils.escapeHtml(token.content);return "<div class=\\"code-block\\"><div class=\\"code-head\\"><span class=\\"code-lang\\">"+(info||"text")+"</span><button class=\\"copy-code\\" type=\\"button\\">Copy</button></div><pre><code>"+code+"</code></pre></div>";};' +
    'return md;}' +
    'function copyText(text,button){function done(ok){button.textContent=ok?"Copied":"Copy";setTimeout(function(){button.textContent="Copy";},1200);} if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(text).then(function(){done(true);}).catch(function(){fallback();});}else{fallback();} function fallback(){var area=document.createElement("textarea");area.value=text;area.setAttribute("readonly","");area.style.position="fixed";area.style.opacity="0";document.body.appendChild(area);area.select();var ok=false;try{ok=document.execCommand("copy");}catch(e){}document.body.removeChild(area);done(ok);}}' +
    'function render(){var root=document.getElementById("content");var md=initMarkdown();root.innerHTML=md.render(source);if(window.renderMathInElement){window.renderMathInElement(root,{delimiters:[{left:"$$",right:"$$",display:true},{left:"\\\\[",right:"\\\\]",display:true},{left:"\\\\(",right:"\\\\)",display:false},{left:"$",right:"$",display:false}],throwOnError:false,ignoredTags:["script","noscript","style","textarea","pre","code"]});}}' +
    'function measureHeight(){var body=document.body;var doc=document.documentElement;var root=document.getElementById("content");var height=Math.max(body?body.scrollHeight:0,doc?doc.scrollHeight:0,root?root.scrollHeight:0,root?root.offsetHeight:0);if(window.markdownBridge&&window.markdownBridge.updateMarkdownHeight){window.markdownBridge.updateMarkdownHeight(String(Math.ceil(height)));}}' +
    'function scheduleMeasure(){measureHeight();setTimeout(measureHeight,40);setTimeout(measureHeight,160);setTimeout(measureHeight,480);}' +
    'if(window.ResizeObserver){new ResizeObserver(scheduleMeasure).observe(document.documentElement);}' +
    'if(window.MutationObserver){new MutationObserver(scheduleMeasure).observe(document.getElementById("content"),{childList:true,subtree:true,characterData:true,attributes:true});}' +
    'window.addEventListener("load",scheduleMeasure);window.addEventListener("resize",scheduleMeasure);' +
    'document.addEventListener("click",function(event){var target=event.target;if(target&&target.classList&&target.classList.contains("copy-code")){var block=target.closest(".code-block");var code=block?block.querySelector("code"):null;copyText(code?code.textContent:"",target);}});' +
    'render();' +
    'scheduleMeasure();' +
    '})();';
}

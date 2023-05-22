import std.stdio;
import std.file;
import std.string;
import std.conv;

enum XmlTokenType
{
    unknown,
    startTagOpen,           // <
    tagClose,               // >
    closingTagOpen,         // </
    singularTagClose,       // />
    propAssign,             // =
    propValueDelimiter,     // "
    whitespace,
    name,
    content,
    specialTagOpen,         // <?
    specialTagClose,        // ?>
    commentOpen,            // <!--
    commentEnd,             // -->
}

struct XmlToken
{
    XmlTokenType type;
    string data;

    this(XmlTokenType type, string data)
    {
        this.type = type;
        this.data = data;
    }
};

bool isWhitespace(char c)
{
    return c == ' ' ||  c == '\n' || c == '\r' || c == '\t';
}

bool isNextChar(size_t i, string xml, char c)
{
    ++i;

    if(i >= xml.length)
        return false;

    return xml[i] == c;
}

bool areNextChars(size_t i, string xml, char[] chars...)
{
    foreach(c; chars) {
        ++i;
        if(i >= xml.length || xml[i] != c)
            return false;
    }

    return true;
}

size_t getWhitespaceLength(size_t i, string xml)
{
    size_t len = 1;
    ++i;

    while(i < xml.length) {
        char c = xml[i];
        if(!isWhitespace(c))
            return len;
        ++len;
        ++i;
    }

    return len;
}

size_t getCommentContentLength(size_t i, string xml)
{
    size_t len = 1;
    ++i;

    while(i < xml.length) {
        char c = xml[i];
        if(c == '-' && areNextChars(i, xml, '-', '>'))
            return len;

        ++len;
        ++i;
    }

    return len;
}

size_t getPropertyContentLength(size_t i, string xml)
{
    size_t len = 1;
    ++i;

    while(i < xml.length) {
        char c = xml[i];
        if(c == '\"')
            return len;

        ++len;
        ++i;
    }

    return len;
}

size_t getElementInnerContentLength(size_t i, string xml)
{
    size_t len = 1;
    ++i;

    while(i < xml.length) {
        char c = xml[i];
        if(c == '<')
            return len;

        ++len;
        ++i;
    }

    return len;
}

size_t getNameLength(size_t i, string xml)
{
    size_t len = 1;
    ++i;

    while(i < xml.length) {
        char c = xml[i];
        if(c == '>' || c == '=' || isWhitespace(c) || (c == '/' && isNextChar(i, xml, '>')))
            return len;

        ++len;
        ++i;
    }

    return len;
}

XmlTokenType getLastXmlTokenType(XmlToken[] tokens, bool includeWhitespace)
{
    if(tokens.length == 0)
        return XmlTokenType.unknown;

    size_t i = tokens.length - 1;
    while(i >= 0)
    {
        if(tokens[i].type != XmlTokenType.whitespace ||
            (tokens[i].type == XmlTokenType.whitespace && includeWhitespace))
        {
            return tokens[i].type;
        }

        --i;
    }

    return tokens[tokens.length - 1].type;
}

XmlTokenType getNextXmlTokenType(size_t i, XmlToken[] tokens)
{
    ++i;
    if(i >= tokens.length)
        return XmlTokenType.unknown;
    else
        return tokens[i].type;
}

XmlToken[] tokenizeXml(string xml)
{
    bool inComment = false;
    size_t i = 0;
    XmlToken[] tokens;

    while(i < xml.length)
    {
        size_t tokenLen = 1;
        char c = xml[i];

        if(inComment)
        {
            if(c == '-' && areNextChars(i, xml, '-', '>'))
            {
                tokenLen = 3;
                tokens ~= XmlToken(XmlTokenType.commentEnd, xml[i..i + tokenLen]);
                inComment = false;
            }
            else
            {
                tokenLen = getCommentContentLength(i, xml);
                tokens ~= XmlToken(XmlTokenType.content, xml[i..i + tokenLen]);
            }
        }
        else if(c == '<')
        {
            if(isNextChar(i, xml, '?'))
            {
                tokenLen = 2;
                tokens ~= XmlToken(XmlTokenType.specialTagOpen, xml[i..i + tokenLen]);
            }
            else if(isNextChar(i, xml, '/'))
            {
                tokenLen = 2;
                tokens ~= XmlToken(XmlTokenType.closingTagOpen, xml[i..i + tokenLen]);
            }
            else if(areNextChars(i, xml, '!', '-', '-'))
            {
                tokenLen = 4;
                tokens ~= XmlToken(XmlTokenType.commentOpen, xml[i..i + tokenLen]);
                inComment = true;
            }
            else
            {
                tokens ~= XmlToken(XmlTokenType.startTagOpen, xml[i..i + tokenLen]);
            }
        }
        else if(c == '?' && isNextChar(i, xml, '>'))
        {
            tokenLen = 2;
            tokens ~= XmlToken(XmlTokenType.specialTagClose, xml[i..i + tokenLen]);
        }
        else if(c == '/' && isNextChar(i, xml, '>'))
        {
            tokenLen = 2;
            tokens ~= XmlToken(XmlTokenType.singularTagClose, xml[i..i + tokenLen]);
        }
        else if(c == '>')
        {
            tokens ~= XmlToken(XmlTokenType.tagClose, xml[i..i + tokenLen]);
        }
        else if(c == '=')
        {
            tokens ~= XmlToken(XmlTokenType.propAssign, xml[i..i + tokenLen]);
        }
        else if(c == '\"')
        {
            tokens ~= XmlToken(XmlTokenType.propValueDelimiter, xml[i..i + tokenLen]);
        }
        else if(isWhitespace(c))
        {
            tokenLen = getWhitespaceLength(i, xml);
            tokens ~= XmlToken(XmlTokenType.whitespace, xml[i..i + tokenLen]);
        }
        else
        {
            auto lastNonWhitespaceTokenType = getLastXmlTokenType(tokens, false);

            if(lastNonWhitespaceTokenType == XmlTokenType.startTagOpen ||
                lastNonWhitespaceTokenType == XmlTokenType.closingTagOpen ||
                lastNonWhitespaceTokenType == XmlTokenType.specialTagOpen ||
                lastNonWhitespaceTokenType == XmlTokenType.name ||
                (lastNonWhitespaceTokenType == XmlTokenType.propValueDelimiter &&
                getLastXmlTokenType(tokens, true) == XmlTokenType.whitespace))
            {
                tokenLen = getNameLength(i, xml);
                tokens ~= XmlToken(XmlTokenType.name, xml[i..i + tokenLen]);
            }
            else if(lastNonWhitespaceTokenType == XmlTokenType.propValueDelimiter)
            {
                tokenLen = getPropertyContentLength(i, xml);
                tokens ~= XmlToken(XmlTokenType.content, xml[i..i + tokenLen]);
            }
            else
            {
                tokenLen = getElementInnerContentLength(i, xml);
                tokens ~= XmlToken(XmlTokenType.content, xml[i..i + tokenLen]);
            }
        }

        i += tokenLen;
    }

    return tokens;
}

void printXmlTokens(XmlToken[] tokens)
{
    writefln("found %s XML tokens", tokens.length);
    writeln("-------------------------------------");
    foreach( token; tokens)
    {
        writefln("%s token (len = %s): '%s'", token.type, token.data.length, token.data);
    }
    writeln("-------------------------------------");
}

struct XmlElement
{
    string name;
    string[] contentParts;
    string[string] properties;
    XmlElement[] children;

    string* getProperty(string name)
    {
        return name in properties;
    }

    XmlElement* getFirstChild(string name)
    {
        foreach(ref child; children)
        {
            if(child.name == name)
                return &child;
        }

        return null;
    }

    XmlElement[] getChildren(string name)
    {
        XmlElement[] res;
        foreach(ref child; children)
        {
            if(child.name == name)
                res ~= child;
        }

        return res;
    }

    bool hasChild(string name)
    {
        return getFirstChild(name) != null;
    }

    bool hasContent()
    {
        return contentParts.length > 0;
    }

    string getCombinedContent()
    {
        size_t totalLen = 0;
        foreach(contentPart; contentParts)
        {
            totalLen += contentPart.length;
        }

        char[] combinedContent;
        combinedContent.length = totalLen;
        size_t i = 0;
        foreach(contentPart; contentParts)
        {
            foreach(char c; contentPart)
            {
                combinedContent[i] = c;
                ++i;
            }
        }

        return cast(string)combinedContent;
    }
}

struct XmlDoc
{
    XmlElement info;
    XmlElement root;
}

XmlElement parseXmlElement(ref size_t i, XmlToken[] tokens)
{
    size_t startI = i;
    XmlElement el;
    string lastPropName = "";
    bool inClosingTag = false;
    bool inComment = false;

    while(i < tokens.length) {
        XmlToken token = tokens[i];

        if(token.type == XmlTokenType.commentOpen)
        {
            inComment = true;
        }
        else if(token.type == XmlTokenType.commentEnd)
        {
            inComment = false;
        }
        if(token.type == XmlTokenType.name)
        {
            if(getNextXmlTokenType(i, tokens) == XmlTokenType.propAssign)
                lastPropName = token.data;
            else if(!el.name)
                el.name = token.data;
        }
        else if(token.type == XmlTokenType.content && !inComment)
        {
            if(getNextXmlTokenType(i, tokens) == XmlTokenType.propValueDelimiter)
            {
                el.properties[lastPropName] = token.data;
            }
            else
            {
                el.contentParts ~= token.data;
            }
        }
        else if(token.type == XmlTokenType.startTagOpen && i != startI)
        {
            XmlElement childEl = parseXmlElement(i, tokens);
            el.children ~= childEl;
        }
        else if(token.type == XmlTokenType.singularTagClose ||
            token.type == XmlTokenType.specialTagClose)
        {
            return el;
        }
        else if(token.type == XmlTokenType.closingTagOpen)
        {
            inClosingTag = true;
        }
        else if(token.type == XmlTokenType.tagClose && inClosingTag)
        {
            return el;
        }

        ++i;
    }

    return el;
}

XmlDoc parseXmlDoc(XmlToken[] tokens)
{
    XmlDoc doc;
    size_t i = 0;

    while(i < tokens.length) {
        XmlToken token = tokens[i];

        if(token.type == XmlTokenType.specialTagOpen)
        {
            doc.info = parseXmlElement(i, tokens);
        }
        else if(token.type == XmlTokenType.startTagOpen)
        {
            doc.root = parseXmlElement(i, tokens);
        }

        ++i;
    }

    return doc;
}

string getXmlElementPrintIndentation(int level)
{
    string res = "";
    for(int i = 0; i < level; ++i)
        res ~= "\t";
    return res;
}

void printXmlElement(XmlElement el, int level)
{
    ++level;
    string indent = getXmlElementPrintIndentation(level);

    writefln("%s {", indent);
    writefln("%s   name: %s", indent, el.name);

    if(el.properties.length == 0)
    {
        writefln("%s   properties: []", indent);
    }
    else
    {
        writefln("%s   properties: [", indent);
        foreach(key, val; el.properties)
        {
            writefln("%s      %s -> %s", indent, key, val);
        }
        writefln("%s   ]", indent);
    }

    if(el.children.length == 0)
    {
        writefln("%s   children: []", indent);
    }
    else
    {
        writefln("%s   children: [", indent);
        foreach(childEl; el.children)
        {
            printXmlElement(childEl, level);
        }
        writefln("%s   ]", indent);
    }

    writefln("%s }", indent);
}

void printXmlDoc(XmlDoc doc)
{
    printXmlElement(doc.root, -1);
}

string[string] getGlTypedefMap()
{
    string[string] glTypedefMap = [
        "GLenum": "uint",
        "GLboolean": "ubyte",
        "GLbitfield": "uint",
        "GLvoid": "void",
        "GLbyte": "byte",
        "GLubyte": "ubyte",
        "GLshort": "short",
        "GLushort": "ushort",
        "GLint": "int",
        "GLuint": "uint",
        "GLclampx": "int",
        "GLsizei": "int",
        "GLfloat": "float",
        "GLclampf": "float",
        "GLdouble": "double",
        "GLclampd": "double",
        "GLeglClientBufferEXT": "void*",
        "GLeglImageOES": "void*",
        "GLchar": "char",
        "GLcharARB": "char",
        "GLhandleARB": "uint",
        "GLhalf": "ushort",
        "GLhalfARB": "ushort",
        "GLfixed": "int",
        "GLintptr": "long",
        "GLintptrARB": "long",
        "GLsizeiptr": "long",
        "GLsizeiptrARB": "long",
        "GLint64": "long",
        "GLint64EXT": "long",
        "GLuint64": "ulong",
        "GLuint64EXT": "ulong",
        "GLsync": "void*",
        "_cl_context": "",
        "_cl_event": "",
        "GLDEBUGPROC": "extern(System) void function(GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length, const GLchar* message, const void* userParam)",
        "GLDEBUGPROCARB": "extern(System) void function(GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length, const GLchar* message, const void* userParam)",
        "GLDEBUGPROCKHR": "extern(System) void function(GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length, const GLchar* message, const void* userParam)",
        "GLDEBUGPROCAMD": "extern(System) void function(GLuint id, GLenum category, GLenum severity, GLsizei length, const GLchar* message, void* userParam)",
        "GLhalfNV": "ushort",
        "GLvdpauSurfaceNV": "long",
        "GLVULKANPROCNV": "extern(System) void function()",
    ];

    return glTypedefMap;
}

struct GlEnum
{
    string name;
    string value;
    string dType;
    bool isDeprecated;

    this(string name, string value, string dType)
    {
        this.name = name;
        this.value = value;
        this.dType = dType;
    }
}

GlEnum[] getGlEnums(XmlElement rootEl)
{
    GlEnum[] res;

    XmlElement[] enumEls = rootEl.getChildren("enums");
    foreach(enumEl; enumEls)
    {
        XmlElement[] enumMemberEls = enumEl.getChildren("enum");
        foreach(enumMemberEl; enumMemberEls)
        {
            string* val = enumMemberEl.getProperty("value");
            string* name = enumMemberEl.getProperty("name");
            string* group = enumMemberEl.getProperty("group");
            string* cType = enumMemberEl.getProperty("type");

            if(val == null || name == null)
                continue;

            string dType = "uint";

            if(cType != null)
            {
                if(*cType == "ull")
                    dType = "ulong";
            }
            else if(group != null)
            {
                string[] groupParts = split(*group, ',');
                foreach(part; groupParts)
                {
                    if(part == "Boolean")
                    {
                        dType = "ubyte";
                        break;
                    }
                }
            }

            res ~= GlEnum(*name, *val, dType);
        }
    }

    return res;
}

GlEnum[string] getGlEnumMap(GlEnum[] glEnums)
{
    GlEnum[string] map;
    foreach(glEnum; glEnums)
    {
        if(glEnum.name in map)
            continue;
        map[glEnum.name] = glEnum;
    }
    return map;
}

string trimEnd(string str)
{
    size_t newLen = str.length;
    while(newLen > 0)
    {
        size_t i = newLen - 1;
        if(!isWhitespace(str[i]))
            break;
        --newLen;
    }

    return str[0..newLen];
}

struct GlCommandParam
{
    CommandType type;
    string name;

    this(string name, CommandType type)
    {
        this.type = type;
        this.name = name;
    }
}

struct GlCommand
{
    string name;
    CommandType returnType;
    GlCommandParam[] params;
    bool isDeprecated;

    this(string name, CommandType returnType)
    {
        this.name = name;
        this.returnType = returnType;
    }
}

string getPrintableGlCommandParamList(GlCommandParam[] params)
{
    string res;

    foreach(i, param; params)
    {
        res ~= param.type.fullType ~ " " ~ param.name;
        if(i != params.length - 1)
            res ~= ", ";
    }

    return res;
}

void printGlCommands(GlCommand[] commands)
{
    writefln("found %s GL commands", commands.length);
    writeln("-------------------------------------");
    foreach(command; commands)
    {
        string params = getPrintableGlCommandParamList(command.params);
        writefln("command '%s' [%s] -> returns '%s'", command.name, params, command.returnType);
    }
    writeln("-------------------------------------");
}

string getCombinedCommandType(string[] contentParts, XmlElement* typeEl)
{
    if(typeEl == null)
        return contentParts[0];

    if(contentParts.length == 0)
    {
        return typeEl.contentParts[0];
    }
    else if(contentParts.length == 1)
    {
        if(indexOf(contentParts[0], '*' != -1))
            return typeEl.contentParts[0] ~= contentParts[0];
        else
            return contentParts[0] ~= typeEl.contentParts[0];
    }
    else
    {
        string res = contentParts[0];
        res ~= typeEl.contentParts[0];
        res ~= contentParts[1];
        return res;
    }
}

enum CTokenType
{
    constStorage,
    typeName,
    pointer,
    whitespace
}

struct CToken
{
    CTokenType type;
    string data;

    this(CTokenType type, string data)
    {
        this.type = type;
        this.data = data;
    }
}

size_t getCTypeNameLength(size_t i, string cType)
{
    size_t len = 1;
    ++i;

    while(i < cType.length) {
        char c = cType[i];
        if(c == '*' || isWhitespace(c))
            return len;
        ++len;
        ++i;
    }

    return len;
}

CToken[] tokenizeCType(string cType)
{
    size_t i = 0;
    CToken[] tokens;

    while(i < cType.length)
    {
        size_t tokenLen = 1;
        char c = cType[i];

        if(c == 'c' && areNextChars(i, cType, 'o', 'n', 's', 't'))
        {
            tokenLen = 5;
            tokens ~= CToken(CTokenType.constStorage, cType[i..i + tokenLen]);
        }
        else if(c == '*')
        {
            tokens ~= CToken(CTokenType.pointer, cType[i..i + tokenLen]);
        }
        else if(isWhitespace(c))
        {
            tokenLen = getWhitespaceLength(i, cType);
            tokens ~= CToken(CTokenType.whitespace, cType[i..i + tokenLen]);
        }
        else
        {
            tokenLen = getCTypeNameLength(i, cType);
            tokens ~= CToken(CTokenType.typeName, cType[i..i + tokenLen]);
        }

        i += tokenLen;
    }

    return tokens;
}

string trimTrailingWhitespace(string str)
{
    size_t newLen = str.length;
    while(newLen > 0)
    {
        char c = str[newLen - 1];
        if(!isWhitespace(c))
            break;
        --newLen;
    }

    return str[0..newLen];
}

struct CommandType
{
    string baseType;
    string fullType;

    this(string baseType, string fullType)
    {
        this.baseType = baseType;
        this.fullType = fullType;
    }
}

CommandType getPatchedCombinedCommandType(string typeString)
{
    typeString = trimTrailingWhitespace(typeString);

    CToken[] tokens = tokenizeCType(typeString);

    bool hasConst = false;
    int pointerCount = 0;
    string baseTypeName;

    foreach(token; tokens)
    {
        if(token.type == CTokenType.constStorage)
            hasConst = true;
        else if(token.type == CTokenType.pointer)
            pointerCount++;
        else if(token.type == CTokenType.typeName)
            baseTypeName = token.data;
    }

    if(!hasConst)
        return CommandType(baseTypeName, typeString);

    string res = "const(";
    res ~= baseTypeName;

    if(pointerCount == 0)
    {
        res ~= ")";
    }
    else if(pointerCount == 1)
    {
        res ~= ")*";
    }
    else
    {
        res ~= "*)";
        for(int i = 0; i < pointerCount - 1; ++i)
            res ~= "*";
    }

    return CommandType(baseTypeName, res);
}

GlCommand[] getGlCommands(XmlElement rootEl)
{
    GlCommand[] res;

    XmlElement* commandsEl = rootEl.getFirstChild("commands");
    if(commandsEl == null)
        return res;

    XmlElement[] commandEls = commandsEl.getChildren("command");
    foreach(commandEl; commandEls)
    {
        XmlElement* protoEl = commandEl.getFirstChild("proto");
        XmlElement* returnTypeEl = protoEl.getFirstChild("ptype");
        CommandType returnType = getPatchedCombinedCommandType(
            getCombinedCommandType(protoEl.contentParts, returnTypeEl));
        XmlElement* commandNameEl = protoEl.getFirstChild("name");

        auto command = GlCommand(commandNameEl.contentParts[0], returnType);

        XmlElement[] paramEls = commandEl.getChildren("param");
        foreach(paramEl; paramEls)
        {
            XmlElement* paramTypeEl = paramEl.getFirstChild("ptype");
            CommandType paramType = getPatchedCombinedCommandType(
                getCombinedCommandType(paramEl.contentParts, paramTypeEl));
            XmlElement* paramNameEl = paramEl.getFirstChild("name");

            string paramName = paramNameEl.contentParts[0];
            if(paramName == "ref")
                paramName = "reference";
            command.params ~= GlCommandParam(paramName, paramType);
        }

        res ~= command;
    }

    return res;
}

GlCommand[string] getGlCommandMap(GlCommand[] glCommands)
{
    GlCommand[string] map;
    foreach(glCommand; glCommands)
    {
        if(glCommand.name in map)
            continue;
        map[glCommand.name] = glCommand;
    }
    return map;
}

enum GlApiType
{
    gl,
    gles
}

struct GlFeature
{
    string name;
    bool isDeprecated;

    this(string name, bool isDeprecated)
    {
        this.name = name;
        this.isDeprecated = isDeprecated;
    }
}

struct GlFeatureSet
{
    GlApiType apiType;
    int majorVersion;
    int minorVersion;

    GlFeature[] enums;
    GlFeature[] commands;

    this(GlApiType apiType, int majorV, int minorV)
    {
        this.apiType = apiType;
        majorVersion = majorV;
        minorVersion = minorV;
    }
}

void appendGlFeatureFromEl(XmlElement el, bool isFromRemoveEl, ref GlFeature[] enums, ref GlFeature[] commands)
{
    string* name = el.getProperty("name");
    if(name == null)
        return;

    GlFeature feature = GlFeature(*name, isFromRemoveEl);

    if(el.name == "enum")
        enums ~= feature;
    else if(el.name == "command")
        commands ~= feature;
}

void getGlFeaturesFromEl(XmlElement parentEl, ref GlFeature[] enums, ref GlFeature[] commands)
{
    XmlElement[] requireEls = parentEl.getChildren("require");
    foreach(requireEl; requireEls)
    {
        foreach(childEl; requireEl.children)
            appendGlFeatureFromEl(childEl, false, enums, commands);
    }

    XmlElement[] removeEls = parentEl.getChildren("remove");
    foreach(removeEl; removeEls)
    {
        foreach(childEl; removeEl.children)
            appendGlFeatureFromEl(childEl, true, enums, commands);
    }
}

GlFeatureSet[] getGlFeatureSets(XmlElement rootEl)
{
    GlFeatureSet[] res;

    XmlElement[] featureEls = rootEl.getChildren("feature");
    foreach(featureEl; featureEls)
    {
        string* apiName = featureEl.getProperty("api");
        if(apiName == null)
            continue;

        GlApiType apiType = GlApiType.gles;
        if(*apiName == "gl")
            apiType = GlApiType.gl;

        string* versionNr = featureEl.getProperty("number");
        string[] versionNrParts = split(*versionNr, '.');
        if(versionNrParts.length != 2)
            continue;
        int majorVer = to!int(versionNrParts[0]);
        int minorVer = to!int(versionNrParts[1]);

        auto featureSet = GlFeatureSet(apiType, majorVer, minorVer);
        getGlFeaturesFromEl(featureEl, featureSet.enums, featureSet.commands);

        res ~= featureSet;
    }

    return res;
}

void printGlFeatureSets(GlFeatureSet[] glFeatureSets)
{
    writefln("found %s GL feature sets", glFeatureSets.length);
    writeln("-------------------------------------");
    foreach(glFeatureSet; glFeatureSets)
    {
        writefln("%s version %s_%s", glFeatureSet.apiType, glFeatureSet.majorVersion,
                 glFeatureSet.minorVersion);

        foreach(enumFeature; glFeatureSet.enums)
        {
            if(enumFeature.isDeprecated)
                writefln("  -> enum %s [DEPRECATED IN CORE]", enumFeature.name);
            else
                writefln("  -> enum %s", enumFeature.name);
        }

        foreach(commandFeature; glFeatureSet.commands)
        {
            if(commandFeature.isDeprecated)
                writefln("  -> command %s [DEPRECATED IN CORE]", commandFeature.name);
            else
                writefln("  -> command %s", commandFeature.name);
        }
    }
    writeln("-------------------------------------");
}

string formDlangFuncDef(GlCommand glCommand)
{
    string res = glCommand.returnType.fullType;
    res ~= " function(";
    foreach(i, param; glCommand.params)
    {
        if(i == glCommand.params.length - 1)
            res ~= param.type.fullType ~ " " ~ param.name;
        else
            res ~= param.type.fullType ~ " " ~ param.name ~ ", ";
    }
    res ~= ")";
    return res;
}

void markDeprecatedEnums(GlEnum[string] glEnumMap, GlFeature[] enumFeatures)
{
    foreach(enumFeature; enumFeatures)
    {
        GlEnum glEnum = glEnumMap[enumFeature.name];
        glEnum.isDeprecated = enumFeature.isDeprecated;
        glEnumMap[enumFeature.name] = glEnum;
    }
}

void markDeprecatedCommands(GlCommand[string] glCommandMap, GlFeature[] commandFeatures)
{
    foreach(commandFeature; commandFeatures)
    {
        GlCommand glCommand = glCommandMap[commandFeature.name];
        glCommand.isDeprecated = commandFeature.isDeprecated;
        glCommandMap[commandFeature.name] = glCommand;
    }
}

void markDeprecatedFeatures(GlFeatureSet[] glFeatureSets, GlExtension[] glExtensions, GlEnum[string] glEnumMap,
    GlCommand[string] glCommandMap, GlApiType apiType, int majorApiVersion, int minorApiVersion)
{
    foreach(glFeatureSet; glFeatureSets)
    {
        if(glFeatureSet.apiType != apiType || glFeatureSet.majorVersion > majorApiVersion || glFeatureSet.minorVersion > minorApiVersion)
            continue;

        markDeprecatedEnums(glEnumMap, glFeatureSet.enums);
        markDeprecatedCommands(glCommandMap, glFeatureSet.commands);
    }

    foreach(glExtension; glExtensions)
    {
        markDeprecatedEnums(glEnumMap, glExtension.enums);
        markDeprecatedCommands(glCommandMap, glExtension.commands);
    }
}

struct RelevantGlFeatures
{
    GlEnum[] enums;
    GlCommand[] commands;
}

void appendRelevantEnums(ref GlEnum[string] relevantEnums, GlEnum[string] glEnumMap, GlFeature[] enumFeatures,
    bool isCoreProfile)
{
    foreach(enumFeature; enumFeatures)
    {
        GlEnum glEnum = glEnumMap[enumFeature.name];
        if(isCoreProfile && glEnum.isDeprecated || glEnum.name in relevantEnums)
            continue;
        relevantEnums[glEnum.name] = glEnum;
    }
}

void appendRelevantCommands(ref GlCommand[string] relevantCommands, GlCommand[string] glCommandMap,
    GlFeature[] commandFeatures, bool isCoreProfile)
{
    foreach(commandFeature; commandFeatures)
    {
        GlCommand glCommand = glCommandMap[commandFeature.name];
        if(isCoreProfile && glCommand.isDeprecated || glCommand.name in relevantCommands)
            continue;
        relevantCommands[glCommand.name] = glCommand;
    }
}

RelevantGlFeatures getRelevantFeatures(GlFeatureSet[] glFeatureSets, GlExtension[] glExtensions, GlEnum[string] glEnumMap,
    GlCommand[string] glCommandMap, GlApiType apiType, bool coreProfile, int majorApiVersion, int minorApiVersion)
{
    GlEnum[string] relevantEnums;
    GlCommand[string] relevantCommands;

    foreach(glFeatureSet; glFeatureSets)
    {
        if(glFeatureSet.apiType != apiType)
            continue;

        if(glFeatureSet.majorVersion > majorApiVersion || glFeatureSet.minorVersion > minorApiVersion)
            continue;

        appendRelevantEnums(relevantEnums, glEnumMap, glFeatureSet.enums, coreProfile);
        appendRelevantCommands(relevantCommands, glCommandMap, glFeatureSet.commands, coreProfile);
    }

    foreach(glExtension; glExtensions)
    {
        appendRelevantEnums(relevantEnums, glEnumMap, glExtension.enums, coreProfile);
        appendRelevantCommands(relevantCommands, glCommandMap, glExtension.commands, coreProfile);
    }

    return RelevantGlFeatures(relevantEnums.values, relevantCommands.values);
}

void writeOutput(string filename, string[string] glTypedefMap, RelevantGlFeatures relevantGlFeatures)
{
    if(exists(filename))
        remove(filename);

    File output = File(filename, "w");

    foreach(glType, dType; glTypedefMap)
    {
        if(dType == "")
            output.writefln("struct %s {}", glType);
        else
            output.writefln("alias %s = %s;", glType, dType);
    }
    output.writeln("");

    foreach(glEnum; relevantGlFeatures.enums)
    {
        if(glEnum.isDeprecated)
            continue;

        output.writefln("enum %s %s = %s;", glEnum.dType, glEnum.name, glEnum.value);
    }
    output.writeln("");

    output.writeln("nothrow @nogc extern(System)");
    output.writeln("{");
    foreach(glCommand; relevantGlFeatures.commands)
    {
        if(glCommand.isDeprecated)
            continue;

        output.writefln("    alias Fn%s = %s;", glCommand.name, formDlangFuncDef(glCommand));
    }
    output.writeln("}");
    output.writeln("");

    foreach(glCommand; relevantGlFeatures.commands)
    {
        if(glCommand.isDeprecated)
            continue;

        output.writefln("Fn%s %s;", glCommand.name, glCommand.name);
    }
    output.writeln("");

    output.writeln("alias FnloadOpenglProc = void* function(const(char)* name);");
    output.writeln("");

    output.writeln("bool loadOpenGlProcs(FnloadOpenglProc loadOpenGlProc)");
    output.writeln("{");
    output.writeln("    bool res = true;");
    foreach(glCommand; relevantGlFeatures.commands)
    {
        if(glCommand.isDeprecated)
            continue;

        output.writefln("    res &= ((%s = cast(Fn%s)loadOpenGlProc(\"%s\")) != null);", glCommand.name, glCommand.name, glCommand.name);
    }
    output.writeln("    return res;");
    output.writeln("}");
}

struct GlExtension
{
    string name;
    GlFeature[] enums;
    GlFeature[] commands;

    this(string name)
    {
        this.name = name;
    }
}

bool isDesiredExtension(string name, string[] desiredExtensionNames)
{
    foreach(desiredExtensionName; desiredExtensionNames)
    {
        if(name == desiredExtensionName)
            return true;
    }

    return false;
}

GlExtension[] getGlExtensions(string[] extensionNames, XmlElement rootEl)
{
    GlExtension[] extensions;

    if(extensionNames.length == 0)
        return extensions;

    XmlElement* extensionsEl = rootEl.getFirstChild("extensions");
    if(extensionsEl == null)
        return extensions;

    XmlElement[] extensionEls = extensionsEl.getChildren("extension");
    foreach(extensionEl; extensionEls)
    {
        string* name = extensionEl.getProperty("name");
        if(name == null || !isDesiredExtension(*name, extensionNames))
            continue;

        GlExtension extension = GlExtension(*name);
        getGlFeaturesFromEl(extensionEl, extension.enums, extension.commands);

        extensions ~= extension;
    }

    return extensions;
}

string[string] getRelevantGlTypedefMap(string[string] glTypedefMap, RelevantGlFeatures relevantGlFeatures)
{
    string[string] relevantTypedefMap;

    foreach(relevantCommand; relevantGlFeatures.commands)
    {
        if(relevantCommand.returnType.baseType in glTypedefMap)
            relevantTypedefMap[relevantCommand.returnType.baseType] = glTypedefMap[relevantCommand.returnType.baseType];

        foreach(param; relevantCommand.params)
        {
            if(param.type.baseType in glTypedefMap)
                relevantTypedefMap[param.type.baseType] = glTypedefMap[param.type.baseType];
        }
    }

    return relevantTypedefMap;
}

void main()
{
    // ---- params to control output ---------------------------------
    string glSpecFilePath = "D:\\dev\\libs\\opengl_spec\\gl.xml";
    GlApiType desiredApiType = GlApiType.gl;
    int desiredMajorVersion = 4;
    int desiredMinorVersion = 6;
    bool coreProfileOnly = true;
    string[] desiredExtensions = [];
    // ---------------------------------------------------------------

    string xml = readText(glSpecFilePath);

    XmlToken[] tokens = tokenizeXml(xml);
    XmlDoc xmlDoc = parseXmlDoc(tokens);

    string[string] glTypedefMap = getGlTypedefMap();

    GlEnum[] glEnums = getGlEnums(xmlDoc.root);
    GlEnum[string] glEnumMap = getGlEnumMap(glEnums);

    GlCommand[] glCommands = getGlCommands(xmlDoc.root);
    GlCommand[string] glCommandMap = getGlCommandMap(glCommands);

    GlFeatureSet[] glFeatureSets = getGlFeatureSets(xmlDoc.root);

    GlExtension[] glExtensions = getGlExtensions(desiredExtensions, xmlDoc.root);

    markDeprecatedFeatures(glFeatureSets, glExtensions, glEnumMap, glCommandMap,
        desiredApiType, desiredMajorVersion, desiredMinorVersion);

    auto relevantGlFeatures = getRelevantFeatures(glFeatureSets, glExtensions, glEnumMap, glCommandMap,
        desiredApiType, coreProfileOnly, desiredMajorVersion, desiredMinorVersion);

    string[string] relevantGlTypedefMap = getRelevantGlTypedefMap(glTypedefMap, relevantGlFeatures);

    writeOutput("output.d", relevantGlTypedefMap, relevantGlFeatures);
}

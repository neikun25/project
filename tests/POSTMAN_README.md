# Postman 测试使用指南

## 快速开始

### 1. 准备测试文件

首先生成测试样例文件：

```bash
cd backend
python tests/gen_samples.py
```

这将在 `tests/samples/` 目录下生成：

- `sample.txt` - 文本文件
- `sample.html` - HTML 文件
- `sample.pdf` - PDF 文件
- `sample.mp3` - MP3 音频文件

### 2. 导入 Postman 集合

1. 打开 Postman
2. 点击 **Import** 按钮
3. 选择 `backend/tests/postman_collection.json` 文件
4. 导入成功后，你会看到 "ConvertEasy API Tests" 集合

### 3. 配置项目路径（重要！）

导入集合后，**必须**配置项目根路径变量：

1. 在 Postman 中打开 "ConvertEasy API Tests" 集合
2. 点击集合名称旁边的 **...** 菜单，选择 **Edit**
3. 切换到 **Variables** 标签
4. 找到 `projectRoot` 变量，将其值修改为你的实际项目路径：

   **Linux/Mac:**

   ```
   /home/jared/converteasy/backend
   ```

   **Windows:**

   ```
   C:/Users/YourName/converteasy/backend
   ```

   ⚠️ 注意：Windows 路径也使用正斜杠 `/`，不是反斜杠 `\`

5. 点击 **Save** 保存配置

### 4. 运行测试

现在可以运行测试了！文件路径已自动配置。

#### 运行单个请求

1. 展开 "ConvertEasy API Tests" 集合
2. 选择任意请求（如 "Health Check"）
3. 点击 **Send** 按钮
4. 查看响应和测试结果（Tests 标签中显示通过/失败）

#### 运行整个集合

1. 点击集合名称旁边的 **▶** (Run) 按钮
2. 在 Collection Runner 中点击 **Run ConvertEasy API Tests**
3. 查看测试结果摘要

## 测试结构

### 1. 健康检查

- **Health Check**: 检查服务是否正常运行

### 2. 格式查询

- **Supported Formats - All**: 获取所有支持的格式
- **Supported Formats - Document**: 获取文档类格式
- **Supported Formats - Audio**: 获取音频类格式
- **Invalid Category (Error Test)**: 测试无效分类的错误处理

### 3. 文件转换

- **Detect Targets - PDF File**: 检测 PDF 可转换的目标格式
- **Upload & Convert - PDF to DOCX**: PDF 转 Word
- **Upload & Convert - Document to PDF**: 文档转 PDF（使用 TXT 文件）
- **Upload & Convert - HTML to PDF**: HTML 转 PDF
- **Upload & Convert - Audio MP3 to WAV**: MP3 转 WAV
- **Get Task Status**: 查询转换任务状态
- **Download Converted File**: 下载转换后的文件

### 4. 错误场景测试

- **Missing File (400)**: 测试缺少文件的错误
- **Invalid Category (400)**: 测试无效分类
- **Unsupported Conversion (400)**: 测试不支持的转换（音频转 PDF）
- **Format Mismatch (400)**: 测试格式不匹配（声称是 PDF 但实际是 TXT）

## 环境变量

集合使用以下变量：

| 变量          | 说明               | 默认值                                                           | 是否需要修改        |
| ------------- | ------------------ | ---------------------------------------------------------------- | ------------------- |
| `baseUrl`     | API 基础地址       | `https://convert-easy-203720-5-1389303207.sh.run.tcloudbase.com` | 仅当 API 地址变更时 |
| `taskId`      | 任务 ID            | （自动保存）                                                     | 不需要              |
| `projectRoot` | 项目根目录绝对路径 | `/home/jared/converteasy/backend`                                | **必须修改**        |

## 文件路径配置原理

所有文件上传请求使用以下格式：

```
{{projectRoot}}/tests/samples/sample.pdf
```

运行时 Postman 会将其解析为：

```
/home/jared/converteasy/backend/tests/samples/sample.pdf
```

这样做的好处：

- ✅ 使用绝对路径，Postman 可以准确找到文件
- ✅ 通过变量管理，适配不同开发环境
- ✅ 团队协作时只需修改一个变量值
- ✅ 无需每个请求单独选择文件

## 注意事项

1. **必须配置 projectRoot 变量**，否则文件上传会失败（400 Bad Request: 缺少文件）
2. 测试样例文件必须存在于 `tests/samples/` 目录
3. 部分测试（如 Download）依赖前面测试保存的 `taskId`
4. 建议按顺序运行完整集合，或先运行上传测试再运行状态查询/下载测试
5. Windows 路径也要使用正斜杠 `/` 而不是反斜杠 `\`

## 故障排查

### 问题：所有上传请求返回 400 "缺少文件"

**原因**：未配置 `projectRoot` 变量或路径不正确

**解决方法**：

1. 编辑集合，进入 Variables 标签
2. 确认 `projectRoot` 值为项目的实际绝对路径
3. 确认 `tests/samples/` 目录存在且包含样例文件
4. 保存后重新运行测试

### 问题：文件路径显示为 {{projectRoot}}/tests/samples/...

**原因**：变量未被正确解析

**解决方法**：

1. 确保在 **Collection** 级别配置了变量，不是 Environment
2. 保存集合后刷新 Postman
3. 检查变量名称是否正确（区分大小写）

### 问题：Get Task Status 返回 404

**原因**：`taskId` 变量为空或无效

**解决方法**：

1. 先运行任意 Upload & Convert 请求
2. 确认响应中包含 `taskId`
3. 变量会自动保存，然后再运行 Get Task Status

## 自动化测试

如果需要完全自动化的测试，推荐使用：

### 方法 1: Newman CLI

```bash
# 安装 Newman
npm install -g newman

# 运行集合（需要先配置好 projectRoot 变量）
newman run tests/postman_collection.json \
  --env-var "projectRoot=/home/jared/converteasy/backend"
```

### 方法 2: Python 集成测试（推荐）

```bash
cd backend
pytest tests/test_integration.py -v
```

Python 集成测试完全自动化，不需要任何手动配置。

## 测试覆盖总结

✅ **正常流程**

- 健康检查
- 格式查询（全部/文档/音频）
- 文件格式检测
- PDF → DOCX 转换
- TXT → PDF 转换
- HTML → PDF 转换
- MP3 → WAV 转换
- 任务状态查询
- 文件下载

✅ **错误场景**

- 无效分类（400）
- 缺少文件（400）
- 不支持的转换（400）
- 格式不匹配（400）

## 更多信息

- 查看单元测试：`pytest tests/ -v`
- 查看集成测试：`pytest tests/test_integration.py -v`
- 生成更多样例：`python tests/gen_samples.py`
- 查看 API 文档：访问 `{{baseUrl}}/docs`

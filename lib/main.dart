import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '西语单词记忆',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

//单词数据模型
class WordItem {
  final String id;
  String spanish;
  String chinese;
  String sentenceEs;
  String sentenceCn;
  int考核SuccessCount;
  bool isInDeepMaster;

  WordItem({
    required this.id,
    required this.spanish,
    required this.chinese,
    required this.sentenceEs,
    required this.sentenceCn,
    this.考核SuccessCount = 0,
    this.isInDeepMaster = false,
  });

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "spanish": spanish,
      "chinese": chinese,
      "sentenceEs": sentenceEs,
      "sentenceCn": sentenceCn,
      "考核SuccessCount":考核SuccessCount,
      "isInDeepMaster":isInDeepMaster
    };
  }

  static WordItem fromJson(Map<String,dynamic> json){
    return WordItem(
      id:json["id"],
      spanish:json["spanish"],
      chinese:json["chinese"],
      sentenceEs:json["sentenceEs"],
      sentenceCn:json["sentenceCn"],
      考核SuccessCount:json["考核SuccessCount"]??0,
      isInDeepMaster:json["isInDeepMaster"]??false
    );
  }
}

//全局状态
class AppState extends ChangeNotifier{
  List<WordItem> unlearnList=[];
  List<WordItem> learnedList=[];
  List<WordItem> reviewList=[];
  List<WordItem> deepMasterList=[];

  int completeLearnDay=0;
  int checkIntervalDay=3;
  int checkDrawCount=10;
  int dayCounter=0;
  bool isCheckDay=false;

  final FlutterTts tts=FlutterTts();
  bool ttsSwitch=true;
  final Uuid uuid=const Uuid();

  Future<void> initTTS()async{
    await tts.setLanguage("es-ES");
    await tts.setSpeechRate(0.85);
  }

  Future<void> speak(String text)async{
    if(!ttsSwitch)return;
    await tts.speak(text);
  }

  Future<void> loadData()async{
    final sp=await SharedPreferences.getInstance();
    completeLearnDay=sp.getInt("completeLearnDay")??0;
    checkIntervalDay=sp.getInt("checkIntervalDay")??3;
    checkDrawCount=sp.getInt("checkDrawCount")??10;
    dayCounter=sp.getInt("dayCounter")??0;
    ttsSwitch=sp.getBool("ttsSwitch")??true;

    //初始化示例单词，智利相关简单例句
    if(!sp.containsKey("initSample")){
      unlearnList.add(WordItem(
        id:uuid.v4(),
        spanish:"casa",
        chinese:"家，房子",
        sentenceEs:"Esta es mi casa.",
        sentenceCn:"这是我的家。"
      ));
      unlearnList.add(WordItem(
        id:uuid.v4(),
        spanish:"comida",
        chinese:"食物",
        sentenceEs:"La comida es rica.",
        sentenceCn:"食物很好吃。"
      ));
      unlearnList.add(WordItem(
        id:uuid.v4(),
        spanish:"sol",
        chinese:"太阳",
        sentenceEs:"El sol brilla mucho en Chile.",
        sentenceCn:"智利的太阳光照很强。"
      ));
      await sp.setBool("initSample",true);
    }
    calcIsCheckDay();
    notifyListeners();
  }

  void calcIsCheckDay(){
    isCheckDay = (dayCounter>0) && (dayCounter % checkIntervalDay ==0);
  }

  Future<void> saveAll()async{
    final sp=await SharedPreferences.getInstance();
    await sp.setInt("completeLearnDay",completeLearnDay);
    await sp.setInt("checkIntervalDay",checkIntervalDay);
    await sp.setInt("checkDrawCount",checkDrawCount);
    await sp.setInt("dayCounter",dayCounter);
    await sp.setBool("ttsSwitch",ttsSwitch);
  }

  //完成普通学习日
  void finishNormalStudy(){
    completeLearnDay++;
    dayCounter++;
    calcIsCheckDay();
    saveAll();
    notifyListeners();
  }

  //完成考核，重置计时
  void finishCheckTask(){
    dayCounter=0;
    calcIsCheckDay();
    saveAll();
    notifyListeners();
  }

  //单词预筛选，收集不认识的候选
  List<WordItem> tempCandidate=[];
  int dailyTarget=3;

  void startPreFilter(){
    tempCandidate.clear();
    notifyListeners();
  }

  void candidateAdd(WordItem w){
    tempCandidate.add(w);
    notifyListeners();
  }

  void candidateKnow(WordItem w){
    learnedList.add(w);
    unlearnList.remove(w);
    notifyListeners();
  }

}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late AppState state;
  @override
  void initState() {
    super.initState();
    state=AppState();
    state.initTTS();
    state.loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title:const Text("西班牙语单词记忆")),
      body:Padding(
        padding:const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("累计完成学习天数：${state.completeLearnDay}",style:const TextStyle(fontSize:16)),
            const SizedBox(height:12),
            if(state.isCheckDay)
              Column(
                children: [
                  const Text("📅今日为考核日",style:TextStyle(fontSize:18,color:Colors.redAccent)),
                  const SizedBox(height:20),
                  Row(
                    mainAxisAlignment:MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(onPressed: (){
                        //学习：正常走新词预筛选，考核计时器不重置
                        state.startPreFilter();
                        Navigator.push(context,MaterialPageRoute(builder: (_)=>PreFilterPage(state:state)));
                      }, child:const Text("学习")),
                      ElevatedButton(onPressed: (){
                        Navigator.push(context,MaterialPageRoute(builder: (_)=>CheckSettingPage(state:state)));
                      }, child:const Text("考核")),
                    ],
                  )
                ],
              )
            else
              ElevatedButton(
                onPressed: (){
                  state.startPreFilter();
                  Navigator.push(context,MaterialPageRoute(builder: (_)=>PreFilterPage(state:state)));
                },
                child:const Text("开始今日学习"),
              ),
            const SizedBox(height:20),
            ElevatedButton(onPressed: (){
              Navigator.push(context,MaterialPageRoute(builder: (_)=>StatPage(state:state)));
            }, child:const Text("统计数据")),
            const SizedBox(height:12),
            ElevatedButton(onPressed: (){
              Navigator.push(context,MaterialPageRoute(builder: (_)=>SettingPage(state:state)));
            }, child:const Text("设置")),
          ],
        ),
      ),
    );
  }
}

//预筛选页面（你的手绘卡片UI）
class PreFilterPage extends StatefulWidget {
  final AppState state;
  const PreFilterPage({super.key,required this.state});

  @override
  State<PreFilterPage> createState() => _PreFilterPageState();
}

class _PreFilterPageState extends State<PreFilterPage> {
  int index=0;
  @override
  Widget build(BuildContext context) {
    AppState state=widget.state;
    if(state.unlearnList.isEmpty){
      return Scaffold(
        appBar: AppBar(title:const Text("预筛选")),
        body:const Center(child:Text("暂无未学习单词，请添加新单词")),
      );
    }
    WordItem current=state.unlearnList[index];
    return Scaffold(
      appBar: AppBar(title:Text("第${index+1}/${state.unlearnList.length} 预筛选")),
      body:Padding(
        padding:const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(alignment:Alignment.topLeft,child:Text("第${state.completeLearnDay+1}天",style:const TextStyle(fontSize:16))),
            Align(alignment:Alignment.topRight,child:SwitchListTile(
              contentPadding:EdgeInsets.zero,
              title:const Text("发音"),
              value:state.ttsSwitch,
              onChanged: (v){
                setState(() {
                  state.ttsSwitch=v;
                  state.saveAll();
                });
              }
            )),
            Expanded(
              child: Card(
                elevation:4,
                child:Padding(
                  padding:const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment:CrossAxisAlignment.stretch,
                    children: [
                      Text(current.spanish,style:const TextStyle(fontSize:28,fontWeight:FontWeight.bold)),
                      const SizedBox(height:8),
                      Text(current.chinese,style:const TextStyle(fontSize:20)),
                      const Divider(height:24),
                      Text(current.sentenceEs,style:const TextStyle(fontSize:16)),
                      const SizedBox(height:4),
                      Text(current.sentenceCn,style:const TextStyle(fontSize:15,color:Colors.grey)),
                      const SizedBox(height:12),
                      ElevatedButton(onPressed: ()async{
                        await state.speak(current.spanish);
                      }, child:const Text("播放单词发音")),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height:20),
            Row(
              children: [
                Expanded(
                  child:SizedBox(
                    height:52,
                    child:OutlinedButton(
                      onPressed: (){
                        //认识，直接加入已学库
                        state.candidateKnow(current);
                        nextCard();
                      },
                      child:const Text("✅认识",style:TextStyle(fontSize:17)),
                    ),
                  ),
                ),
                const SizedBox(width:12),
                Expanded(
                  child:SizedBox(
                    height:52,
                    child:ElevatedButton(
                      onPressed: (){
                        //不认识，加入候选池
                        state.candidateAdd(current);
                        nextCard();
                      },
                      child:const Text("❌不认识",style:TextStyle(fontSize:17)),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void nextCard(){
    AppState state=widget.state;
    setState(() {
      index++;
    });
    if(index>=state.unlearnList.length){
      //预筛选结束，进入正式学习阶段
      Navigator.pushReplacement(context,MaterialPageRoute(builder: (_)=>FormalStudyPage(state:state)));
    }
  }
}

//正式学习阶段，5种题型页面（简化框架）
class FormalStudyPage extends StatelessWidget {
  final AppState state;
  const FormalStudyPage({super.key,required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title:const Text("正式学习阶段")),
      body:Center(
        child:Column(
          mainAxisAlignment:MainAxisAlignment.center,
          children: [
            const Text("完整5种题型逻辑待运行，当前框架已搭建",textAlign:TextAlign.center),
            const SizedBox(height:30),
            ElevatedButton(onPressed: (){
              state.finishNormalStudy();
              Navigator.popUntil(context, (route) => route.isFirst);
            }, child:const Text("完成今日学习，返回首页"))
          ],
        ),
      ),
    );
  }
}

//考核设置页面
class CheckSettingPage extends StatelessWidget {
  final AppState state;
  const CheckSettingPage({super.key,required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title:const Text("周期考核")),
      body:const Center(child:Text("考核题型逻辑占位页面")),
      floatingActionButton: FloatingActionButton(
        child:const Icon(Icons.check),
        onPressed: (){
          state.finishCheckTask();
          Navigator.popUntil(context, (r)=>r.isFirst);
        },
      ),
    );
  }
}

//统计页面
class StatPage extends StatelessWidget {
  final AppState state;
  const StatPage({super.key,required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title:const Text("统计数据")),
      body:Padding(
        padding:const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:CrossAxisAlignment.start,
          children: [
            Text("累计完成学习天数：${state.completeLearnDay}",style:const TextStyle(fontSize:17)),
            const SizedBox(height:10),
            Text("未学习单词数量：${state.unlearnList.length}",style:const TextStyle(fontSize:17)),
            Text("已学习单词数量：${state.learnedList.length}",style:const TextStyle(fontSize:17)),
            Text("生词复习池：${state.reviewList.length}",style:const TextStyle(fontSize:17)),
            Text("深度掌握库：${state.deepMasterList.length}",style:const TextStyle(fontSize:17)),
          ],
        ),
      ),
    );
  }
}

//设置页面
class SettingPage extends StatefulWidget {
  final AppState state;
  const SettingPage({super.key,required this.state});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  @override
  Widget build(BuildContext context) {
    AppState state=widget.state;
    return Scaffold(
      appBar: AppBar(title:const Text("设置")),
      body: ListView(
        children: [
          ListTile(
            title:const Text("考核间隔天数"),
            subtitle:Text("当前：${state.checkIntervalDay}天"),
          ),
          ListTile(
            title:const Text("单次考核抽取单词数量"),
            subtitle:Text("当前：${state.checkDrawCount}个"),
          ),
          SwitchListTile(
            title:const Text("单词TTS发音开关"),
            value:state.ttsSwitch,
            onChanged: (v){
              setState(() {
                state.ttsSwitch=v;
                state.saveAll();
              });
            },
          )
        ],
      ),
    );
  }
}

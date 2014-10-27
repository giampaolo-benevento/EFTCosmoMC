
import os, sys, pickle, ResultObjs, time, copy


def readobject(directory=None):
    if directory == None:
        directory = sys.argv[1]
    with open(os.path.abspath(directory) + os.sep + 'batch.pyobj', 'rb') as inp:
        return pickle.load(inp)

def saveobject(obj, filename):
        with open(filename, 'wb') as output:
            pickle.dump(obj, output, pickle.HIGHEST_PROTOCOL)

def makePath(s):
    if not os.path.exists(s): os.makedirs(s)

def nonEmptyFile(fname):
    return os.path.exists(fname) and os.path.getsize(fname) > 0


class dataSet:
    def __init__(self, names, params=None, covmat=None, dist_settings={}):
        if isinstance(names, basestring): names = [names]
        if params is None: params = [(name + '.ini') for name in names]
        else: params = self.standardizeParams(params)
        if covmat is not None: self.covmat = covmat
        self.names = names
        self.params = params  # can be an array of items, either ini file name or dictionaries of parameters
        self.tag = "_".join(self.names)
        self.dist_settings = dist_settings

    def add(self, name, params=None, overrideExisting=True, dist_settings={}):
        if params is None: params = [name]
        params = self.standardizeParams(params)
        self.dist_settings.update(dist_settings)
        if overrideExisting:
            self.params = params + self.params  # can be an array of items, either ini file name or dictionaries of parameters
        else:
            self.params += params
        if name is not None:
            self.names += [name]
            self.tag = "_".join(self.names)

    def addEnd(self, name, params, dist_settings={}):
        self.add(name, params, overrideExisting=False, dist_settings=dist_settings)

    def extendForImportance(self, names, params):
        data = copy.deepcopy(self)
        data.tag += '_post_' + "_".join(names)
        data.importanceNames = names
        data.importanceParams = data.standardizeParams(params)
        data.names += data.importanceNames
        data.params += data.importanceParams
        return data

    def standardizeParams(self, params):
        if isinstance(params, dict) or isinstance(params, basestring): params = [params]
        for i in range(len(params)):
            if isinstance(params[i], basestring) and not '.ini' in params[i]: params[i] += '.ini'
        return params

    def hasName(self, name):
        if isinstance(name, basestring): return name in self.names
        else: return any([True for i in name if i in self.names])

    def hasAll(self, name):
        if isinstance(name, basestring): return name in self.names
        else: return all([(i in self.names) for i in name])

    def tagReplacing(self, x, y):
        items = []
        for name in self.names:
            if name == x:
                if y != '': items.append(y)
            else: items.append(name)
        return "_".join(items)

    def namesReplacing(self, dic):
        if dic is None: return self.names
        items = []
        for name in self.names:
            if name in dic:
                val = dic[name]
                if val: items.append(val)
            else: items.append(name)
        return items


class jobGroup:
    def __init__(self, name, params=[[]], importanceRuns=[], datasets=[]):
            self.params = params
            self.groupName = name
            self.importanceRuns = importanceRuns
            self.datasets = datasets

class importanceSetting:
    def __init__(self, names, inis=[], dist_settings={}):
        self.names = names
        self.inis = inis
        self.dist_settings = dist_settings

    def wantImportance(self, jobItem):
        return True

class jobItem:

    def __init__(self, path, param_set, data_set, base='base'):
        self.param_set = param_set
        if not isinstance(data_set, dataSet): data_set = dataSet(data_set[0], data_set[1])
        self.data_set = data_set
        self.base = base
        self.paramtag = "_".join([base] + param_set)
        self.datatag = data_set.tag
        self.name = self.paramtag + '_' + self.datatag
        self.batchPath = path
        self.relativePath = self.paramtag + os.sep + self.datatag + os.sep
        self.chainPath = path + self.relativePath
        self.chainRoot = self.chainPath + self.name
        self.distPath = self.chainPath + 'dist' + os.sep
        self.distRoot = self.distPath + self.name
        self.isImportanceJob = False
        self.importanceItems = []
        self.result_converge = None
        self.group = None
        self.dist_settings = copy.copy(data_set.dist_settings)
        self.makeIDs()

    def iniFile(self, variant=''):
        if not self.isImportanceJob:
            return self.batchPath + 'iniFiles' + os.sep + self.name + variant + '.ini'
        else: return self.batchPath + 'postIniFiles' + os.sep + self.name + variant + '.ini'

    def makeImportance(self, importanceRuns):
        self.importanceItems = []
        for impRun in importanceRuns:
            if isinstance(impRun, importanceSetting):
                if not impRun.wantImportance(self): continue
            else:
                if len(impRun) > 2 and not impRun[2].wantImportance(self): continue
                impRun = importanceSetting(impRun[0], impRun[1])
            if len(set(impRun.names).intersection(self.data_set.names)) > 0:
                print 'importance job duplicating parent data set:' + self.name
                continue
            data = self.data_set.extendForImportance(impRun.names, impRun.inis)
            job = jobItem(self.batchPath, self.param_set, data)
            job.importanceTag = "_".join(impRun.names)
            job.importanceSettings = impRun.inis
            tag = '_post_' + job.importanceTag
            job.name = self.name + tag
            job.chainRoot = self.chainRoot + tag
            job.distPath = self.distPath
            job.chainPath = self.chainPath
            job.relativePath = self.relativePath
            job.distRoot = self.distRoot + tag
            job.datatag = self.datatag + tag
            job.isImportanceJob = True
            job.parent = self
            job.group = self.group
            job.dist_settings.update(impRun.dist_settings)
            job.makeIDs()
            self.importanceItems.append(job)

    def makeNormedName(self, dataSubs=None):
        normed_params = "_".join(sorted(self.param_set))
        normed_data = "_".join(sorted(self.data_set.namesReplacing(dataSubs)))
        normed_name = self.base
        if len(normed_params) > 0: normed_name += '_' + normed_params
        normed_name += '_' + normed_data
        return normed_name, normed_params, normed_data

    def makeIDs(self):
        self.normed_name, self.normed_params, self.normed_data = self.makeNormedName()

    def matchesDatatag(self, tagList):
        if self.datatag in tagList or self.normed_data in tagList: return True
        return self.datatag.replace('_post', '') in  [tag.replace('_post', '') for tag in tagList]

    def importanceJobs(self):
        return self.importanceItems

    def makeChainPath(self):
        makePath(self.chainPath)
        return self.chainPath

    def writeIniLines(self, f):
        outfile = open(self.iniFile(), 'w')
        outfile.write("\n".join(f))
        outfile.close()

    def chainName(self, chain=1):
        return self.chainRoot + '_' + str(chain) + '.txt'

    def chainExists(self, chain=1):
        fname = self.chainName(chain)
        return nonEmptyFile(fname)

    def allChainExists(self, num_chains):
        return all([self.chainExists(i + 1) for i in range(num_chains)])

    def chainFileDate(self, chain=1):
        return os.path.getmtime(self.chainName(chain))

    def chainsDodgy(self, interval=600):
        dates = []
        i = 1
        while os.path.exists(self.chainName(i)):
            dates.append(os.path.getmtime(self.chainName(i)))
            i += 1
        return os.path.exists(self.chainName(i + 1)) or max(dates) - min(dates) > interval

    def notRunning(self):
        if not self.chainExists(): return False  # might be in queue
        lastWrite = self.chainFileDate()
        return lastWrite < time.time() - 5 * 60

    def chainMinimumExists(self):
        fname = self.chainRoot + '.minimum'
        return nonEmptyFile(fname)

    def chainBestfit(self, paramNameFile=None):
        bf_file = self.chainRoot + '.minimum'
        if nonEmptyFile(bf_file):
            return ResultObjs.bestFit(bf_file, paramNameFile)
        return None

    def chainMinimumConverged(self):
        bf = self.chainBestfit()
        if bf is None: return False
        return bf.logLike < 1e29

    def convergeStat(self):
        fname = self.chainRoot + '.converge_stat'
        if not nonEmptyFile(fname): return None, None
        textFileHandle = open(fname)
        textFileLines = textFileHandle.readlines()
        textFileHandle.close()
        return float(textFileLines[0].strip()), len(textFileLines) > 1 and textFileLines[1].strip() == 'Done'

    def chainFinished(self):
        done = self.convergeStat()[1]
        if done is None: return False
        return done

    def wantCheckpointContinue(self, minR=0):
        R, done = self.convergeStat()
        if R is None: return False
        if not os.path.exists(self.chainRoot + '_1.chk'): return False
        return not done and R > minR

    def getDistExists(self):
        return os.path.exists(self.distRoot + '.margestats')

    def getDistNeedsUpdate(self):
        return self.chainExists() and (not self.getDistExists() or self.chainFileDate() > os.path.getmtime(self.distRoot + '.margestats'))

    def parentChanged(self):
        return (not self.chainExists() or self.chainFileDate() < self.parent.chainFileDate())

    def R(self):
        if self.result_converge is None:
            fname = self.distRoot + '.converge'
            if not nonEmptyFile(fname): return None
            self.result_converge = ResultObjs.convergeStats(fname)
        return float(self.result_converge.worstR())

    def hasConvergeBetterThan(self, R, returnNotExist=False):
        try:
            chainR = self.R()
            if chainR is None: return returnNotExist
            return chainR <= R
        except:
            print 'WARNING: Bad .converge for ' + self.name
            return returnNotExist

    def loadJobItemResults(self, paramNameFile=None, bestfit=True, bestfitonly=False, noconverge=False, silent=False):
        self.result_converge = None
        self.result_marge = None
        self.result_likemarge = None
        self.result_bestfit = self.chainBestfit(paramNameFile)
        if not bestfitonly:
            marge_root = self.distRoot
            if self.getDistExists():
                if not noconverge: self.result_converge = ResultObjs.convergeStats(marge_root + '.converge')
                self.result_marge = ResultObjs.margeStats(marge_root + '.margestats', paramNameFile)
                self.result_likemarge = ResultObjs.likeStats(marge_root + '.likestats')
                if self.result_bestfit is not None and bestfit: self.result_marge.addBestFit(self.result_bestfit)
            elif not silent: print 'missing: ' + marge_root


class batchJob:

    def __init__(self, path, iniDir):
        self.batchPath = path
        self.skip = []
        self.basePath = os.path.dirname(sys.path[0]) + os.sep
        self.commonPath = self.basePath + iniDir
        self.subBatches = []
        self.jobItems = None

    def makeItems(self, dataAndParams):
            self.jobItems = []
            for group in dataAndParams:
                for data_set in group.datasets:
                    for param_set in group.params:
                        item = jobItem(self.batchPath, param_set, data_set)
                        if hasattr(group, 'groupName'): item.group = group.groupName
                        if not item.name in self.skip:
                            item.makeImportance(group.importanceRuns)
                            self.jobItems.append(item)
            for item in self.items():
                for x in [imp for imp in item.importanceJobs()]:
                    if self.has_normed_name(x.normed_name):
                        print 'replacing importance sampling run with full run: ' + x.name
                        item.importanceItems.remove(x)
            for item in self.items():
                for x in [imp for imp in item.importanceJobs()]:
                    if self.has_normed_name(x.normed_name, wantImportance=True, exclude=x):
                        print 'removing duplicate importance sampling run: ' + x.name
                        item.importanceItems.remove(x)


    def items(self, wantSubItems=True, wantImportance=False):
        for item in self.jobItems:
            yield(item)
            if wantImportance:
                for imp in item.importanceJobs():
                    if not imp.name in self.skip: yield(imp)

        if wantSubItems:
            for subBatch in self.subBatches:
                for item in subBatch.items(wantSubItems, wantImportance): yield(item)

    def hasName(self, name, wantSubItems=True):
        for jobItem in self.items(wantSubItems):
            if jobItem.name == name: return True
        return False

    def has_normed_name(self, name, wantSubItems=True, wantImportance=False, exclude=None):
        return self.normed_name_item(name, wantSubItems, wantImportance, exclude) is not None

    def normed_name_item(self, name, wantSubItems=True, wantImportance=False, exclude=None):
        for jobItem in self.items(wantSubItems, wantImportance):
            if jobItem.normed_name == name and not jobItem is exclude: return jobItem
        return None

    def normalizeDataTag(self, tag):
        return "_".join(sorted(tag.replace('_post', '').split('_')))

    def resolveName(self, paramtag, datatag, wantSubItems=True, wantImportance=True, raiseError=True, base='base', returnJobItem=False):
        if paramtag:
            if isinstance(paramtag, basestring): paramtag = paramtag.split('_')
            paramtags = [base] + sorted(paramtag)
        else:
            paramtag = [base]
            paramtags = [base]
        name = "_".join(paramtags) + '_' + self.normalizeDataTag(datatag)
        jobItem = self.normed_name_item(name, wantSubItems, wantImportance)
        if jobItem is not None: return (jobItem.name, jobItem)[returnJobItem]
        if raiseError: raise Exception('No match for paramtag, datatag... ' + "_".join(paramtag) + ', ' + datatag)
        else: return None

    def save(self, filename=''):
        saveobject(self, (self.batchPath + 'batch.pyobj', filename)[filename != ''])


    def makeDirectories(self):
            makePath(self.batchPath)
            makePath(self.batchPath + 'iniFiles')
            makePath(self.batchPath + 'postIniFiles')


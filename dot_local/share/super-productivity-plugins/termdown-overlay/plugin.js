(() => {
  'use strict';

  const STATE_DIR = '/home/gus/.local/state/super-productivity-waybar-timer';
  const TIMER_FILE = `${STATE_DIR}/active.json`;
  const TODAY_FILE = `${STATE_DIR}/today.json`;
  const HEARTBEAT_FILE = `${STATE_DIR}/heartbeat.json`;
  const REQUEST_FILE = `${STATE_DIR}/start-task.json`;
  const CONTROL_FILE = `${STATE_DIR}/session-control.json`;
  const ALERT_FILE = `${STATE_DIR}/session-alert.json`;
  let operationQueue = Promise.resolve();
  let pollTimer = null;
  let heartbeatTimer = null;
  let refreshTimer = null;
  let pollInFlight = false;
  let lastTodayJson = '';
  let trackedTaskId = null;
  let activeSession = null;
  let pendingSession = null;
  let pausedSession = null;
  let pausePendingTaskId = null;
  let ignoreNextPauseStopEvent = false;
  let hasShownError = false;

  const showError = (error) => {
    const message = error instanceof Error ? error.message : String(error);
    console.error('[Super Productivity Waybar Timer]', message);

    if (!hasShownError) {
      hasShownError = true;
      PluginAPI.showSnack({
        msg: `Waybar task picker: ${message}`,
        type: 'ERROR',
      });
    }
  };

  const runNodeScript = async (script) => {
    if (typeof PluginAPI.executeNodeScript !== 'function') {
      throw new Error('Node execution is unavailable. This plugin requires the desktop app.');
    }

    const result = await PluginAPI.executeNodeScript({ timeout: 5000, script });
    if (!result?.success) {
      const detail =
        typeof result?.error === 'string'
          ? result.error
          : result?.error?.message || 'Could not access the local task state.';
      throw new Error(detail);
    }
    return result.result;
  };

  const writeJsonFile = async (filePath, value) => {
    const serialized = JSON.stringify(value);
    await runNodeScript(`
      const fs = require('fs');
      const path = require('path');
      const file = ${JSON.stringify(filePath)};
      const data = ${serialized};

      fs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 });
      const tempFile = file + '.' + Date.now() + '.' + Math.random().toString(16).slice(2) + '.tmp';
      fs.writeFileSync(tempFile, JSON.stringify(data), { encoding: 'utf8', mode: 0o600 });
      fs.renameSync(tempFile, file);
      return true;
    `);
  };

  const removeFile = async (filePath) => {
    await runNodeScript(`
      const fs = require('fs');
      const file = ${JSON.stringify(filePath)};
      try {
        fs.unlinkSync(file);
      } catch (error) {
        if (error.code !== 'ENOENT') throw error;
      }
      return true;
    `);
  };

  const readAndRemoveJson = async (filePath) =>
    runNodeScript(`
      const fs = require('fs');
      const file = ${JSON.stringify(filePath)};
      if (!fs.existsSync(file)) return null;
      const text = fs.readFileSync(file, 'utf8');
      fs.unlinkSync(file);
      try { return JSON.parse(text); } catch { return null; }
    `);

  const getLogicalDay = (timestamp, startOfNextDayDiffMs) => {
    const date = new Date(Number(timestamp) - startOfNextDayDiffMs);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  };

  const getPlannedTasks = async () => {
    const day = await PluginAPI.getDayContext();
    const tasks = await PluginAPI.getTasks();
    const taskById = new Map(tasks.map((task) => [task.id, task]));
    const todayTasks = tasks
      .filter((task) => {
        if (!task || task.isDone) return false;
        if (
          task.subTaskIds?.length &&
          !task.subTaskIds.some((subTaskId) => !taskById.get(subTaskId)?.isDone)
        ) {
          return false;
        }
        const plannedDay = task.dueWithTime
          ? getLogicalDay(task.dueWithTime, day.startOfNextDayDiffMs)
          : task.dueDay;
        return plannedDay === day.todayStr;
      })
      .map((task) => {
        const reportedTimeSpentMs = Math.max(0, Number(task.timeSpent) || 0);
        const currentSession = activeSession?.taskId === task.id ? activeSession : null;
        const pausedTaskSession = pausedSession?.taskId === task.id ? pausedSession : null;
        const sessionTimeSpentMs = currentSession
          ? currentSession.timeSpentMsAtStart + Math.max(0, Date.now() - currentSession.startedAtMs)
          : pausedTaskSession?.timeSpentMs ?? 0;

        return {
          id: task.id,
          title: String(task.title || 'Untitled task').replace(/\s+/g, ' ').trim(),
          timeEstimateMs: Math.max(0, Number(task.timeEstimate) || 0),
          timeSpentMs: Math.max(reportedTimeSpentMs, sessionTimeSpentMs),
        };
      });

    return { todayStr: day.todayStr, tasks: todayTasks };
  };

  const refreshTodayTasks = async () => {
    const today = await getPlannedTasks();
    const serialized = JSON.stringify(today);
    if (serialized === lastTodayJson) return;

    await writeJsonFile(TODAY_FILE, today);
    lastTodayJson = serialized;
  };

  const writeRunningTimer = async (task, session = null) => {
    await writeJsonFile(TIMER_FILE, {
      taskId: String(task.id || ''),
      title: String(task.title || 'Super Productivity task'),
      timeEstimateMs: Math.max(0, Number(task.timeEstimate) || 0),
      timeSpentMs: Math.max(0, Number(task.timeSpent) || 0),
      startedAtMs: session?.startedAtMs ?? Date.now(),
      sessionState: session ? 'running' : null,
      sessionDurationMs: session?.durationMs ?? 0,
      sessionRemainingMs: session
        ? Math.max(0, session.startedAtMs + session.durationMs - Date.now())
        : 0,
      sessionEndsAtMs: session ? session.startedAtMs + session.durationMs : 0,
    });
  };

  const writePausedTimer = async (session) => {
    await writeJsonFile(TIMER_FILE, {
      taskId: session.taskId,
      title: session.title,
      timeEstimateMs: session.timeEstimateMs,
      timeSpentMs: session.timeSpentMs,
      startedAtMs: Date.now(),
      sessionState: 'paused',
      sessionDurationMs: session.durationMs,
      sessionRemainingMs: session.remainingMs,
      sessionEndsAtMs: 0,
    });
  };

  const syncCurrentTask = async (task, session = null) => {
    if (!task) {
      trackedTaskId = null;
      if (pausePendingTaskId) return;
      activeSession = null;
      pausedSession = null;
      await removeFile(TIMER_FILE);
      return;
    }

    trackedTaskId = task.id;
    let nextSession = session && session.taskId === task.id ? session : null;
    if (!nextSession && activeSession?.taskId === task.id) nextSession = activeSession;
    if (!nextSession && pausedSession?.taskId === task.id) {
      nextSession = {
        taskId: task.id,
        title: String(task.title || pausedSession.title),
        durationMs: pausedSession.remainingMs,
        startedAtMs: Date.now(),
        timeEstimateMs: Math.max(0, Number(task.timeEstimate) || pausedSession.timeEstimateMs),
        timeSpentMsAtStart: Math.max(
          Math.max(0, Number(task.timeSpent) || 0),
          pausedSession.timeSpentMs,
        ),
      };
    }
    activeSession = nextSession;
    pausedSession = null;
    await writeRunningTimer(task, activeSession);
  };

  const refreshSoon = () => {
    if (refreshTimer !== null) return;
    refreshTimer = setTimeout(() => {
      refreshTimer = null;
      refreshTodayTasks().catch(showError);
    }, 250);
  };

  const startSession = async (taskId, sessionMinutes) => {
    const today = await getPlannedTasks();
    const selectedTask = today.tasks.find((task) => task.id === taskId);
    if (!selectedTask) {
      await refreshTodayTasks();
      PluginAPI.showSnack({
        msg: 'That task is no longer unfinished and planned for today.',
        type: 'WARNING',
      });
      return;
    }

    const task = (await PluginAPI.getTasks()).find((item) => item.id === taskId);
    if (!task || task.isDone) {
      PluginAPI.showSnack({ msg: 'That task is no longer available.', type: 'WARNING' });
      return;
    }

    const session = {
      taskId,
      title: String(task.title || 'Super Productivity task'),
      durationMs: sessionMinutes * 60_000,
      startedAtMs: Date.now(),
      timeEstimateMs: Math.max(0, Number(task.timeEstimate) || 0),
      timeSpentMsAtStart: Math.max(0, Number(task.timeSpent) || 0),
    };
    const previousSession = activeSession;
    pendingSession = session;
    pausedSession = null;

    try {
      await PluginAPI.startTracking(taskId);
      trackedTaskId = taskId;
      activeSession = session;
      pendingSession = null;
      // Also updates the session when this task was already tracked and the app
      // therefore emitted no currentTaskChange event.
      await writeRunningTimer(task, session);
    } catch (error) {
      pendingSession = null;
      activeSession = previousSession;
      showError(error);
    }
  };

  const pauseSession = async () => {
    if (!activeSession || trackedTaskId !== activeSession.taskId) return;
    const session = activeSession;
    const pausedAtMs = Date.now();
    const elapsedMs = Math.max(0, pausedAtMs - session.startedAtMs);
    const remainingMs = Math.max(0, session.durationMs - elapsedMs);
    if (remainingMs <= 0) {
      await endSession();
      return;
    }

    pausePendingTaskId = session.taskId;
    ignoreNextPauseStopEvent = true;
    try {
      await PluginAPI.stopTracking();
      const latestTask = (await PluginAPI.getTasks()).find((task) => task.id === session.taskId);
      const timeSpentMs = Math.max(
        session.timeSpentMsAtStart + elapsedMs,
        Math.max(0, Number(latestTask?.timeSpent) || 0),
      );
      pausedSession = {
        taskId: session.taskId,
        title: String(latestTask?.title || session.title),
        durationMs: session.durationMs,
        remainingMs,
        timeEstimateMs: Math.max(0, Number(latestTask?.timeEstimate) || session.timeEstimateMs),
        timeSpentMs,
      };
      activeSession = null;
      trackedTaskId = null;
      await writePausedTimer(pausedSession);
      refreshSoon();
    } catch (error) {
      ignoreNextPauseStopEvent = false;
      activeSession = session;
      showError(error);
    } finally {
      pausePendingTaskId = null;
    }
  };

  const resumeSession = async () => {
    if (!pausedSession || pausedSession.remainingMs <= 0) {
      await endSession();
      return;
    }
    const task = (await PluginAPI.getTasks()).find((item) => item.id === pausedSession.taskId);
    if (!task || task.isDone) {
      await endSession();
      PluginAPI.showSnack({ msg: 'The paused task is no longer available.', type: 'WARNING' });
      return;
    }

    const session = {
      taskId: task.id,
      title: String(task.title || pausedSession.title),
      durationMs: pausedSession.remainingMs,
      startedAtMs: Date.now(),
      timeEstimateMs: Math.max(0, Number(task.timeEstimate) || pausedSession.timeEstimateMs),
      timeSpentMsAtStart: Math.max(
        Math.max(0, Number(task.timeSpent) || 0),
        pausedSession.timeSpentMs,
      ),
    };
    pendingSession = session;
    pausedSession = null;
    try {
      await PluginAPI.startTracking(task.id);
      trackedTaskId = task.id;
      activeSession = session;
      pendingSession = null;
      await writeRunningTimer(task, session);
    } catch (error) {
      pendingSession = null;
      pausedSession = {
        ...session,
        remainingMs: session.durationMs,
        timeSpentMs: session.timeSpentMsAtStart,
      };
      activeSession = null;
      await writePausedTimer(pausedSession);
      showError(error);
    }
  };

  const endSession = async () => {
    const session = activeSession || pausedSession;
    if (!session) return;
    const wasRunning = Boolean(activeSession);
    activeSession = null;
    pendingSession = null;
    pausedSession = null;

    try {
      if (wasRunning && trackedTaskId === session.taskId) {
        await PluginAPI.stopTracking();
      }
      trackedTaskId = null;
      await removeFile(TIMER_FILE);
      PluginAPI.showSnack({
        msg: 'Session ended early. The task remains open and actual time is kept.',
        type: 'INFO',
      });
    } catch (error) {
      if (wasRunning) activeSession = session;
      else pausedSession = session;
      showError(error);
    }
  };

  const handleControlRequest = async () => {
    const request = await readAndRemoveJson(CONTROL_FILE);
    switch (request?.action) {
      case 'pause':
        await pauseSession();
        break;
      case 'resume':
        await resumeSession();
        break;
      case 'end':
        await endSession();
        break;
    }
  };

  const handleStartRequest = async () => {
    const request = await readAndRemoveJson(REQUEST_FILE);
    const taskId = typeof request?.taskId === 'string' ? request.taskId : '';
    const sessionMinutes = Number(request?.sessionMinutes);
    if (!taskId || !Number.isInteger(sessionMinutes) || sessionMinutes < 1 || sessionMinutes > 480) return;
    await startSession(taskId, sessionMinutes);
  };

  const stopExpiredSession = async () => {
    if (!activeSession || Date.now() < activeSession.startedAtMs + activeSession.durationMs) return;
    const expiredSession = activeSession;
    if (trackedTaskId !== expiredSession.taskId) {
      activeSession = null;
      return;
    }

    activeSession = null;
    try {
      await PluginAPI.stopTracking();
      trackedTaskId = null;
      await writeJsonFile(ALERT_FILE, {
        id: `${Date.now()}-${expiredSession.taskId}`,
        title: expiredSession.title,
        createdAtMs: Date.now(),
      });
      await removeFile(TIMER_FILE);
      PluginAPI.showSnack({
        msg: 'Allocated session finished. The task remains open and its actual time is logged.',
        type: 'INFO',
      });
    } catch (error) {
      activeSession = expiredSession;
      showError(error);
    }
  };

  const poll = async () => {
    if (pollInFlight) return;
    pollInFlight = true;
    try {
      await handleControlRequest();
      await handleStartRequest();
      await stopExpiredSession();
    } catch (error) {
      showError(error);
    } finally {
      pollInFlight = false;
    }
  };

  const writeHeartbeat = () => writeJsonFile(HEARTBEAT_FILE, { updatedAtMs: Date.now() });

  const restorePausedSession = async () => {
    const state = await runNodeScript(`
      const fs = require('fs');
      const file = ${JSON.stringify(TIMER_FILE)};
      if (!fs.existsSync(file)) return null;
      try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch { return null; }
    `);
    if (state?.sessionState === 'paused' && state.taskId) {
      pausedSession = {
        taskId: state.taskId,
        title: state.title || 'Super Productivity task',
        durationMs: Number(state.sessionDurationMs) || Number(state.sessionRemainingMs) || 0,
        remainingMs: Number(state.sessionRemainingMs) || 0,
        timeEstimateMs: Number(state.timeEstimateMs) || 0,
        timeSpentMs: Number(state.timeSpentMs) || 0,
      };
    }
  };

  const initialize = async () => {
    if (pollTimer !== null) return;
    try {
      await restorePausedSession();
      await refreshTodayTasks();
      await writeHeartbeat();
    } catch (error) {
      showError(error);
    }
    pollTimer = setInterval(poll, 500);
    heartbeatTimer = setInterval(() => writeHeartbeat().catch(showError), 5000);
  };

  PluginAPI.registerHook(PluginAPI.Hooks.CURRENT_TASK_CHANGE, (payload) => {
    const task = payload?.current || null;
    if (!task && pausePendingTaskId) {
      ignoreNextPauseStopEvent = false;
      trackedTaskId = null;
      return Promise.resolve();
    }
    if (!task && ignoreNextPauseStopEvent) {
      ignoreNextPauseStopEvent = false;
      trackedTaskId = null;
      return Promise.resolve();
    }
    if (task) ignoreNextPauseStopEvent = false;
    const session = task && pendingSession?.taskId === task.id
      ? pendingSession
      : task && activeSession?.taskId === task.id
        ? activeSession
        : null;
    operationQueue = operationQueue
      .catch(showError)
      .then(() => syncCurrentTask(task, session))
      .catch(showError);
    refreshSoon();
    return operationQueue;
  });

  PluginAPI.registerHook(PluginAPI.Hooks.DATA_CHANGED, refreshSoon);
  PluginAPI.registerHook(PluginAPI.Hooks.DAY_CHANGE, refreshSoon);

  if (typeof PluginAPI.onReady === 'function') {
    PluginAPI.onReady(initialize);
  } else {
    initialize();
  }

  PluginAPI.onUnload?.(() => {
    if (pollTimer !== null) clearInterval(pollTimer);
    if (heartbeatTimer !== null) clearInterval(heartbeatTimer);
    if (refreshTimer !== null) clearTimeout(refreshTimer);
  });

  console.info('[Super Productivity Waybar Timer] Ready');
})();
